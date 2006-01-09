<?xml version="1.0"?>
<protocol
    comment = "OpenAMQ server protocol methods"
    script  = "asl_gen"
    chassis = "server"
    >
<inherit name = "amq_cluster" />
<inherit name = "asl_server" />
<inherit name = "amq" />

<option name = "product_name" value = "OpenAMQ Server" />

<!-- CHANNEL -->

<class name = "channel">
  <action name = "flow">
    amq_server_channel_flow (channel, method->active);
  </action>
</class>

<!-- EXCHANGE -->

<class name = "exchange">
  <action name = "declare">
    <local>
    amq_exchange_t
        *exchange;
    int
        exchange_type = 0;
    </local>
    //
    exchange_type = amq_exchange_type_lookup (method->type);
    if (exchange_type) {
        //  Find exchange and create if necessary
        exchange = amq_exchange_search (amq_vhost->exchange_table, method->exchange);
        if (!exchange) {
            if (method->passive)
                amq_server_channel_error (channel, ASL_NOT_FOUND, "No such exchange defined");
            else {
                if (ipr_str_prefixed (method->exchange, "amq."))
                    amq_server_channel_error (channel,
                        ASL_ACCESS_REFUSED, "Exchange name not allowed");
                else {
                    exchange = amq_exchange_new (
                        amq_vhost->exchange_table,
                        amq_vhost,
                        exchange_type,
                        method->exchange,
                        method->durable,
                        method->auto_delete,
                        method->internal);

                    if (exchange) {
                        //  Tell cluster that exchange is being created
                        if (connection->type != AMQ_CONNECTION_TYPE_CLUSTER
                        &&  amq_cluster->enabled)
                            amq_cluster_forward (amq_cluster, amq_vhost, self, TRUE, FALSE);
                    }
                    else
                        amq_server_connection_error (connection,
                            ASL_RESOURCE_ERROR, "Unable to declare exchange");
                }
            }
        }
        if (exchange) {
            if (exchange->type == exchange_type)
                amq_server_agent_exchange_declare_ok (
                    connection->thread, channel->number);
            else
                amq_server_connection_error (connection,
                    ASL_NOT_ALLOWED, "Exchange exists with different type");

            amq_exchange_unlink (&exchange);
        }
    }
    else
        amq_server_connection_error (connection, ASL_COMMAND_INVALID, "Unknown exchange type");
  </action>

  <action name = "delete">
    <local>
    amq_exchange_t
        *exchange;
    </local>
    exchange = amq_exchange_search (amq_vhost->exchange_table, method->exchange);
    if (exchange) {
        //  Tell client delete was successful
        amq_server_agent_exchange_delete_ok (connection->thread, channel->number);

        //  Tell cluster to delete exchange
        if (connection->type != AMQ_CONNECTION_TYPE_CLUSTER
        &&  amq_cluster->enabled)
            amq_cluster_forward (amq_cluster, amq_vhost, self, TRUE, FALSE);

        amq_exchange_destroy (&exchange);
    }
    else
        amq_server_channel_error (channel, ASL_NOT_FOUND, "No such exchange defined");
  </action>
</class>

<!-- QUEUE -->

<class name = "queue">
  <action name = "declare">
    <local>
    amq_queue_t
        *queue;
    static qbyte
        queue_index = 0;
    icl_shortstr_t
        queue_name;
    </local>
    //
    //  Find queue and create if necessary
    if (*method->queue)
        icl_shortstr_cpy (queue_name, method->queue);
    else
        icl_shortstr_fmt (queue_name, "tmp_%06d", icl_atomic_inc32 (&queue_index));

    queue = amq_queue_table_search (amq_vhost->queue_table, queue_name);
    if (!queue) {
        if (method->passive)
            amq_server_channel_error (channel, ASL_NOT_FOUND, "No such queue defined");
        else {
            queue = amq_queue_new (
                amq_vhost,
                connection? connection->id: "",
                queue_name,
                method->durable,
                method->exclusive,
                method->auto_delete);
            if (queue) {
                //  Make default binding, if wanted
                if (amq_vhost->default_exchange)
                    amq_exchange_bind_queue (
                        amq_vhost->default_exchange, NULL, queue, queue->name, NULL);

                //  Add to connection's exclusive queue list
                if (method->exclusive)
                    amq_server_connection_own_queue (connection, queue);

                //  Tell cluster that a new shared queue is starting
                if (connection->type != AMQ_CONNECTION_TYPE_CLUSTER
                &&  amq_cluster->enabled) {
                    if (method->exclusive)
                        //  Forward private queue default binding to all nodes
                        amq_cluster_forward_bind (amq_cluster, amq_vhost,
                            NULL, queue->name, NULL);
                    else
                        //  Forward shared queue creation to all nodes
                        amq_cluster_forward (amq_cluster, amq_vhost, self, TRUE, FALSE);
                }
            }
            else
                amq_server_connection_error (connection,
                    ASL_RESOURCE_ERROR, "Unable to declare queue");
        }
    }
    if (queue) {
        //TODO: verify this in cluster context
        if (method->exclusive
        &&  strneq (queue->owner_id, connection->id))
            amq_server_channel_error (
                channel, 
                ASL_ACCESS_REFUSED,
                "Queue cannot be made exclusive to this connection");
        else
            amq_server_agent_queue_declare_ok (
                connection->thread,
                channel->number,
                queue->name,
                amq_queue_message_count (queue),
                amq_queue_consumer_count (queue));

        amq_queue_unlink (&queue);
    }
    else
        amq_server_channel_error (channel, ASL_NOT_FOUND, "No such queue defined");
  </action>

  <action name = "bind">
    <local>
    amq_exchange_t
        *exchange;                      //  Exchange to bind to
    amq_queue_t
        *queue;
    </local>
    exchange = amq_exchange_search (amq_vhost->exchange_table, method->exchange);
    if (exchange) {
        queue = amq_queue_table_search (amq_vhost->queue_table, method->queue);
        if (queue) {
            amq_exchange_bind_queue (
                exchange, channel, queue, method->routing_key, method->arguments);
            amq_server_agent_queue_bind_ok (
                connection->thread, channel->number);

            //  Tell cluster about new queue binding
            if (connection->type != AMQ_CONNECTION_TYPE_CLUSTER) {
                if (queue->clustered)
                    //  Private queue bindings are replicated using the
                    //  Cluster.Bind method so that each primary server 
                    //  knows to send messages back to this server
                    amq_cluster_forward_bind (amq_cluster, amq_vhost,
                        method->exchange, method->routing_key, method->arguments);
                else
                if (amq_cluster->enabled)
                    //  Shared queue bindings are replicated as-is
                    amq_cluster_forward (amq_cluster, amq_vhost, self, TRUE, FALSE);
            }
            amq_queue_unlink (&queue);
        }
        else
            amq_server_channel_error (channel, ASL_NOT_FOUND, "No such queue defined");
        amq_exchange_unlink (&exchange);
    }
    else
        amq_server_channel_error (channel, ASL_NOT_FOUND, "No such exchange defined");
  </action>

  <action name = "delete">
    <local>
    amq_queue_t
        *queue;
    </local>
    queue = amq_queue_table_search (amq_vhost->queue_table, method->queue);
    if (queue) {
        //  Tell client we deleted the queue ok
        amq_server_agent_queue_delete_ok (
            connection->thread, channel->number, amq_queue_message_count (queue));
                
        //  Tell cluster that queue is being deleted
        if (connection->type != AMQ_CONNECTION_TYPE_CLUSTER
        &&  queue->clustered)
            amq_cluster_forward (amq_cluster, amq_vhost, self, TRUE, FALSE);

        amq_queue_destroy (&queue);
    }
    else
        amq_server_channel_error (channel, ASL_NOT_FOUND, "No such queue defined");
  </action>

  <action name = "purge">
    <local>
    amq_queue_t
        *queue;
    </local>
    queue = amq_queue_table_search (amq_vhost->queue_table, method->queue);
    if (queue) {
        amq_queue_purge (queue, channel);

        //  Tell cluster to also purge shared queue (not stateful)
        if (connection->type != AMQ_CONNECTION_TYPE_CLUSTER
        &&  queue->clustered)
            amq_cluster_forward (amq_cluster, amq_vhost, self, FALSE, FALSE);

        amq_queue_unlink (&queue);
    }
    else
        amq_server_channel_error (channel, ASL_NOT_FOUND, "No such queue defined");
  </action>
</class>

<!-- Basic -->

<class name = "basic">
  <action name = "consume">
    <local>
    amq_queue_t
        *queue;
    </local>
    if (strlen (method->consumer_tag) > 127
    &&  connection->type != AMQ_CONNECTION_TYPE_CLUSTER)
        amq_server_connection_error (connection,
            ASL_SYNTAX_ERROR, "Consumer tag exceeds limit of 127 chars");
    else {
        queue = amq_queue_table_search (amq_vhost->queue_table, method->queue);
        if (queue) {
            //  The channel is responsible for creating/cancelling consumers
            amq_server_channel_consume (channel, queue, self);
            amq_queue_unlink (&queue);
        }
        else
            amq_server_channel_error (channel, ASL_NOT_FOUND, "No such queue defined");
    }
  </action>

  <action name = "publish">
    <local>
    static qbyte
        sequence = 0;                   //  For intra-cluster broadcasting
    amq_exchange_t
        *exchange;
    </local>
    if (*method->exchange)
        //  Lookup exchange specified in method
        exchange = amq_exchange_search (amq_vhost->exchange_table, method->exchange);
    else
        //  Get default exchange for virtual host
        exchange = amq_exchange_link (amq_vhost->default_exchange);

    if (exchange) {
        if (!exchange->internal || strnull (method->exchange)) {
            //  This method may only come from an external application
            assert (connection);
            self->sequence = ++sequence;
            amq_content_$(class.name)_set_routing_key (
                self->content,
                method->exchange,
                method->routing_key,
                connection->id);

            //  Set cluster-id on fresh content coming from applications
            if (amq_cluster->enabled && connection->type != AMQ_CONNECTION_TYPE_CLUSTER)
                amq_content_$(class.name)_set_cluster_id (self->content, channel->cluster_id);

            amq_exchange_publish (exchange, channel, self);
        }
        else
            amq_server_channel_error (channel,
                ASL_ACCESS_REFUSED, "Exchange is for internal use only");

        amq_exchange_unlink (&exchange);
    }
    else
        amq_server_channel_error (channel, ASL_NOT_FOUND, "No such exchange defined");
  </action>

  <action name = "get">
    <local>
    amq_queue_t
        *queue;
    </local>
    queue = amq_queue_table_search (amq_vhost->queue_table, method->queue);
    if (queue) {
        amq_queue_get (queue, channel, self->class_id);
        amq_queue_unlink (&queue);
    }
    else
        amq_server_channel_error (channel, ASL_NOT_FOUND, "No such queue defined");
  </action>

  <action name = "cancel">
    amq_server_channel_cancel (channel, method->consumer_tag, TRUE);
  </action>
</class>

<!-- File -->
<class name = "file">
  <action name = "consume" sameas = "basic" />
  <action name = "publish" sameas = "basic" />
  <action name = "cancel"  sameas = "basic" />
</class>

<!-- Cluster -->

<class name = "cluster">
  <action name = "publish">
    method = NULL;    //  Prevent compiler warning on unused method variable  
    if (connection->type == AMQ_CONNECTION_TYPE_CLUSTER)
        amq_cluster_accept (amq_cluster, self->content, channel);
    else
        amq_server_connection_error (connection, ASL_NOT_ALLOWED, "Method not allowed");
  </action>
</class>

</protocol>
