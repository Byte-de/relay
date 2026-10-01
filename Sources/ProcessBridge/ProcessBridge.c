#include "ProcessBridge.h"
#include <libproc.h>
#include <sys/sysctl.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <limits.h>

int ds_list_pids(int32_t *buffer, int capacity) {
    if (!buffer || capacity <= 0) return proc_listallpids(NULL, 0);
    return proc_listallpids(buffer, capacity * (int)sizeof(int32_t));
}

int ds_read_process(int32_t pid, DSProcessInfo *info) {
    if (pid <= 0 || !info) return 0;
    struct proc_bsdinfo bsd = {0};
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, sizeof(bsd)) != sizeof(bsd)) return 0;
    memset(info, 0, sizeof(*info));
    info->pid = pid;
    info->parent_pid = bsd.pbi_ppid;
    info->uid = bsd.pbi_uid;
    info->status = bsd.pbi_status;
    info->start_seconds = bsd.pbi_start_tvsec;
    info->start_microseconds = bsd.pbi_start_tvusec;
    strlcpy(info->name, bsd.pbi_name[0] ? bsd.pbi_name : bsd.pbi_comm, sizeof(info->name));
    proc_pidpath(pid, info->executable, sizeof(info->executable));
    struct proc_taskinfo task = {0};
    if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &task, sizeof(task)) == sizeof(task)) {
        info->has_metrics = 1;
        info->resident_bytes = task.pti_resident_size;
        info->cpu_nanoseconds = task.pti_total_user + task.pti_total_system;
    }
    struct proc_vnodepathinfo paths = {0};
    if (proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &paths, sizeof(paths)) == sizeof(paths)) {
        strlcpy(info->working_directory, paths.pvi_cdir.vip_path, sizeof(info->working_directory));
    }
    return 1;
}

int ds_read_arguments(int32_t pid, char *buffer, size_t capacity) {
    if (pid <= 0 || !buffer || capacity == 0) return -1;
    int mib[] = { CTL_KERN, KERN_PROCARGS2, pid };
    size_t length = 1024 * 1024;
    char *raw = malloc(length);
    if (!raw) return -1;
    if (sysctl(mib, 3, raw, &length, NULL, 0) != 0 || length < sizeof(int)) {
        free(raw);
        return -1;
    }
    int argc = 0;
    memcpy(&argc, raw, sizeof(argc));
    const char *cursor = raw + sizeof(argc), *end = raw + length;
    // Skip the executable path and the kernel's alignment padding.
    while (cursor < end && *cursor) cursor++;
    while (cursor < end && !*cursor) cursor++;
    size_t written = 0;
    for (int index = 0; index < argc && cursor < end; index++) {
        size_t size = strnlen(cursor, (size_t)(end - cursor));
        if (cursor + size >= end || written + size + 1 > capacity) {
            free(raw);
            return -1;
        }
        memcpy(buffer + written, cursor, size + 1);
        written += size + 1;
        cursor += size + 1;
    }
    free(raw);
    return (int)written;
}
