/*---------------------------------------------------------------------------
 *  amq_stdc_channel.h - Interface of CHANNEL object 
 *
 *  Copyright (c) 2004-2005 JPMorgan
 *  Copyright (c) 1991-2005 iMatix Corporation
 *---------------------------------------------------------------------------*/

#ifndef AMQ_STDC_CHANNEL_H_INCLUDED
#define AMQ_STDC_CHANNEL_H_INCLUDED

#include "amq_stdc_private.h"

typedef struct tag_channel_fsm_context_t* channel_fsm_t;

#include "amq_stdc_connection_fsm.h"
#include "amq_stdc_handle_fsm.h"

#include "amq_stdc_channel_fsm.i"

/*---------------------------------------------------------------------------
 *  Helper functions (public)
 *---------------------------------------------------------------------------*/

apr_status_t channel_get_handle (
    channel_fsm_t     context,
    dbyte             handle_id,
    handle_fsm_t      *handle);

#endif
