/*===========================================================================
 *
 *  amq_core.h   OpenAMQ client & server kernel core
 *
 *  This header file is intended for applications that use the OpenAMQ core
 *  for their work, E.G. client layers.
 *
 *  Copyright (c) 2004-2005 JPMorgan and iMatix Corporation
 *===========================================================================*/

#include "icl.h"                        /*  iCL base classes                 */
#include "smt.h"                        /*  iMatix SMT threading kernel      */

#ifndef __AMQ_CORE_INCLUDED__
#define __AMQ_CORE_INCLUDED__

#include "sfl.h"                        /*  iMatix SFL portability library   */

#define AMQ_SERVER_PORT            "7654"
#define AMQ_SERVER_CONFIG          "amq_server.cfg"
#define AMQ_VHOST_CONFIG           "amq_vhost.cfg"
#define AMQ_CUSTOM_CONFIG          "amq_custom.cfg"

#define AMQP_ID                     128
#define AMQP_VERSION                1
#define AMQP_FRAME_MIN              1024

#define AMQP_SERVICE_QUEUE          1
#define AMQP_SERVICE_TOPIC          2
#define AMQP_SERVICE_EITHER         3
#define AMQP_SERVICE_SUBSCR         999     /*  Internal use only            */

#define AMQP_REPLY_SUCCESS          200
#define AMQP_MESSAGE_NOT_FOUND      310
#define AMQP_MESSAGE_TOO_LARGE      311
#define AMQP_CLIENT_ACTIVE          320
#define AMQP_INVALID_SERVICE        401
#define AMQP_INVALID_PATH           402
#define AMQP_ACCESS_REFUSED         403
#define AMQP_NOT_FOUND              404
#define AMQP_FRAME_ERROR            501
#define AMQP_SYNTAX_ERROR           502
#define AMQP_COMMAND_INVALID        503
#define AMQP_CHANNEL_ERROR          504
#define AMQP_HANDLE_ERROR           505
#define AMQP_RESOURCE_ERROR         506
#define AMQP_NOT_ALLOWED            507
#define AMQP_NOT_IMPLEMENTED        540
#define AMQP_INTERNAL_ERROR         541
#define AMQP_INVALID_MESSAGE        542

/*  AMQ RFC 006 defines 10 priority levels, from 0 to 9                      */

#define AMQP_MAX_PRIORITIES         10

#ifdef __cplusplus
extern "C" {
#endif

void  amq_set_server_name    (char *name);
void  amq_set_server_text    (char *text);

int   amq_server_core        (int argc, char *argv []);
int   amq_user_modules       (void);

#ifdef __cplusplus
}
#endif

#endif