/*
 * Minimal pthread shim for single-threaded Emscripten builds.
 * FFmpeg 7.1's scheduler (ffmpeg_sched.c) uses raw pthread types
 * and functions. This header provides stub implementations so the
 * code compiles without -s USE_PTHREADS=1.
 *
 * pthread_create runs the function synchronously (single-threaded).
 * This works for simple pipelines but may deadlock for complex
 * multi-stage producer-consumer patterns.
 */
#ifndef PTHREAD_SHIM_H
#define PTHREAD_SHIM_H

#include <errno.h>
#include <stddef.h>

/* Only define if not already provided by a real pthread.h */
#ifndef _PTHREAD_H

typedef unsigned long pthread_t;
typedef int pthread_mutex_t;
typedef int pthread_cond_t;
typedef int pthread_once_t;
typedef void *pthread_attr_t;
typedef void *pthread_mutexattr_t;
typedef void *pthread_condattr_t;

#define PTHREAD_MUTEX_INITIALIZER 0
#define PTHREAD_ONCE_INIT 0

/* --- Thread --- */
static inline int pthread_create(pthread_t *thread, const pthread_attr_t *attr,
                                 void *(*start_routine)(void *), void *arg) {
  (void)attr;
  if (thread)
    *thread = 0;
  start_routine(arg);
  return 0;
}

static inline int pthread_join(pthread_t thread, void **retval) {
  (void)thread;
  if (retval)
    *retval = NULL;
  return 0;
}

static inline pthread_t pthread_self(void) { return 0; }

/* --- Mutex --- */
static inline int pthread_mutex_init(pthread_mutex_t *m,
                                     const pthread_mutexattr_t *a) {
  (void)a;
  if (m)
    *m = 0;
  return 0;
}
static inline int pthread_mutex_destroy(pthread_mutex_t *m) {
  (void)m;
  return 0;
}
static inline int pthread_mutex_lock(pthread_mutex_t *m) {
  (void)m;
  return 0;
}
static inline int pthread_mutex_unlock(pthread_mutex_t *m) {
  (void)m;
  return 0;
}

static inline int pthread_mutexattr_init(pthread_mutexattr_t *a) {
  (void)a;
  return 0;
}
static inline int pthread_mutexattr_destroy(pthread_mutexattr_t *a) {
  (void)a;
  return 0;
}
static inline int pthread_mutexattr_settype(pthread_mutexattr_t *a, int t) {
  (void)a;
  (void)t;
  return 0;
}

/* --- Condition Variable --- */
static inline int pthread_cond_init(pthread_cond_t *c,
                                    const pthread_condattr_t *a) {
  (void)a;
  if (c)
    *c = 0;
  return 0;
}
static inline int pthread_cond_destroy(pthread_cond_t *c) {
  (void)c;
  return 0;
}
static inline int pthread_cond_signal(pthread_cond_t *c) {
  (void)c;
  return 0;
}
static inline int pthread_cond_broadcast(pthread_cond_t *c) {
  (void)c;
  return 0;
}
static inline int pthread_cond_wait(pthread_cond_t *c, pthread_mutex_t *m) {
  (void)c;
  (void)m;
  return 0;
}
static inline int pthread_cond_timedwait(pthread_cond_t *c, pthread_mutex_t *m,
                                         const void *abstime) {
  (void)c;
  (void)m;
  (void)abstime;
  return ETIMEDOUT;
}

/* --- Once --- */
static inline int pthread_once(pthread_once_t *once, void (*routine)(void)) {
  if (once && !*once) {
    routine();
    *once = 1;
  }
  return 0;
}

#endif /* _PTHREAD_H */
#endif /* PTHREAD_SHIM_H */
