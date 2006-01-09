<?xml?>
<class
    name      = "amq_queue_base"
    comment   = "Queue manager base class"
    version   = "1.0"
    copyright = "Copyright (c) 2004-2005 iMatix Corporation"
    script    = "icl_gen"
    abstract  = "1"
    >
<doc>
This class provides a template for content queue classes and
especially for consumer registration and cancellation, which is
independent of the queue content type.
</doc>

<inherit class = "icl_object">
    <option name = "alloc" value = "cache" />
</inherit>

<import class = "amq_server_classes" />

<context>
    amq_queue_t
        *queue;                         //  Parent queue
    amq_consumer_by_queue_t
        *active_consumers,              //  Active consumers
        *paused_consumers;              //  Paused consumers
    ipr_looseref_list_t
        *content_list;                  //  List of message contents

    //  Statistics
    size_t
        accept_count,                   //  Number of messages accepted
        dispatch_count;                 //  Number of messages dispatched
</context>

<method name = "new">
    <argument name = "queue" type = "amq_queue_t *">Parent queue</argument>
    //
    self->queue            = queue;
    self->active_consumers = amq_consumer_by_queue_new ();
    self->paused_consumers = amq_consumer_by_queue_new ();
    self->content_list     = ipr_looseref_list_new ();
</method>

<method name = "destroy">
    <footer>
    s_free_consumer_queue (&self->active_consumers);
    s_free_consumer_queue (&self->paused_consumers);
    ipr_looseref_list_destroy (&self->content_list);
    </footer>
</method>

<method name = "consume" template = "function">
    <doc>
    Attach consumer to appropriate queue consumer list.
    </doc>
    <argument name = "consumer" type = "amq_consumer_t *">Consumer reference</argument>
    <argument name = "active"   type = "Bool">Create active consumer?</argument>
    //
    if (active)
        amq_consumer_by_queue_queue (self->active_consumers, consumer);
    else
        amq_consumer_by_queue_queue (self->paused_consumers, consumer);
</method>

<method name = "cancel" template = "function">
    <doc>
    Cancel consumer.  This method synchronises with the server_channel
    cancel method so each party handles their consumer lists separately.
    </doc>
    <argument name = "consumer" type = "amq_consumer_t *">Consumer reference</argument>
    //
    //  Consumer must have been removed from its per-channel list
    assert (consumer->by_channel_next == consumer);
    amq_consumer_destroy (&consumer);
</method>

<method name = "flow" template = "function">
    <doc>
    Pause or restart consumer.
    </doc>
    <argument name = "consumer" type = "amq_consumer_t *">Consumer reference</argument>
    <argument name = "active"   type = "Bool">Active consumer?</argument>
    //
    amq_consumer_by_queue_remove (consumer);
    if (active) {
        amq_consumer_by_queue_queue (self->active_consumers, consumer);
        amq_queue_pre_dispatch (self->queue);
    }
    else
        amq_consumer_by_queue_queue (self->paused_consumers, consumer);
</method>

<method name = "consumer count" template = "function">
    <doc>
    Return number of active consumers for queue.
    </doc>
    //
    rc = amq_consumer_by_queue_count (self->active_consumers);
</method>

<method name = "message count" template = "function">
    <doc>
    Returns number of messages on queue.
    </doc>
    //
    rc = ipr_looseref_list_count (self->content_list);
</method>

<private name = "header">
static amq_consumer_t *
    s_get_next_consumer ($(selftype) *self, char *producer_id, char *cluster_id);
static void
    s_free_consumer_queue (amq_consumer_by_queue_t **queue);
</private>

<private name = "footer">
//  Return next consumer for queue, NULL if there are none.
//  - producer_id is used for local consumers,
//  - cluster_id across the cluster

static amq_consumer_t *
s_get_next_consumer ($(selftype) *self, char *producer_id, char *cluster_id)
{
    amq_consumer_t
        *consumer;

    //  We expect to process the first consumer on the active list
    consumer = amq_consumer_by_queue_first (self->active_consumers);
    while (consumer) {
        if (amq_server_channel_alive (consumer->channel) && consumer->channel->active) {
            if (consumer->no_local == FALSE)
                break;                  //  We have our consumer
            else
            if (consumer->channel->connection->type == AMQ_CONNECTION_TYPE_CLUSTER) {
                //  If the consumer is a cluster peer then the consumer tag is
                //  spid/connectionid/xxx where xxx is the original consumer
                //  tag.  We can compare this with the content cluster_id, which
                //  is spid/connectionid/channelnbr.
                char
                    *slash;
                size_t
                    id_size = 0;        //  Size of spid/connectionid string
                Bool
                    ids_match;          //  Do the two IDs match?

                //  Compare the leading part of both id strings...
                slash = strchr (cluster_id, '/');
                if (slash)
                    slash = strchr (slash + 1, '/');
                if (slash)
                    id_size = slash - cluster_id;
                if (strlen (consumer->tag) > id_size
                &&  memcmp (cluster_id, consumer->tag, id_size) == 0)
                    ids_match = TRUE;
                else
                    ids_match = FALSE;

                if (!ids_match)
                    break;              //  We have our consumer
            }
            else
            if (strneq (consumer->channel->connection->id, producer_id))
                //  If the consumer is an application then we can compare the
                //  content producer_id with the connection id of the consumer.
                break;                  //  We have our consumer
        }
        else
            consumer = amq_consumer_by_queue_next (&consumer);
    }
    return (consumer);
}

static void
s_free_consumer_queue (amq_consumer_by_queue_t **queue)
{
    amq_consumer_t
        *consumer,
        *consumer_ref;

    while ((consumer = amq_consumer_by_queue_pop (*queue))) {
        if (amq_server_channel_cancel (consumer->channel, consumer->tag, FALSE)) {
            consumer_ref = consumer;
            amq_consumer_unlink  (&consumer_ref);
            amq_consumer_destroy (&consumer);
        }
        else
            amq_consumer_unlink (&consumer);
    }
    amq_consumer_by_queue_destroy (queue);
}
</private>

<method name = "selftest" />

</class>
