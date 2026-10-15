// Shim de <os/log.h> para la verificación de sintaxis sin una Mac: solo los
// nombres que usa gl_utils.h (el formato real de os_log no es printf).
#pragma once
typedef unsigned char os_log_type_t;
#define OS_LOG_TYPE_INFO ((os_log_type_t)0x01)
#define OS_LOG_TYPE_ERROR ((os_log_type_t)0x10)
#define OS_LOG_DEFAULT ((void*)0)
#define os_log_with_type(log, type, format, ...) ((void)(log), (void)(type))
