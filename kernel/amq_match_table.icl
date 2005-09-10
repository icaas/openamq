<?xml?>
<class
    name      = "amq_match_table"
    comment   = "Implements the hash table container for the matcher class"
    version   = "1.0"
    script    = "icl_gen"
    >
<doc>
This class is a hash table container for the match class.  This class
works together with the hitset class to perform the matching on topic
names and field values.
</doc>

<inherit class = "ipr_hash_table" />
<import class = "amq_match" />
<option name = "childname" value = "amq_match" />
<!-- This limits the number of topics we can handle to 100k or so -->
<option name = "hash_size" value = "150000" />

<context>
    amq_topic_array_t
        *topics;
</context>

<method name = "new">
    self->topics = amq_topic_array_new ();
</method>

<method name = "destroy">
    amq_topic_array_destroy (&self->topics);
</method>

<method name = "parse topic" template = "function">
    <doc>
    Parse a topic name specifier and derive topic terms from it.  We compare
    the topic name specifier with each existing topic destination and create
    a term for each match.
    </doc>
    <argument name = "subscr" type = "amq_subscr_t *">Subscription to register</argument>
    <local>
    amq_topic_t
        *topic;                         /*  Vhost topic                      */
    amq_match_t
        *match;                         /*  Match item                       */
    ipr_regexp_t
        *regexp;                        /*  Regular expression object        */
    int
        topic_nbr;                      /*  Topic index                      */
    ipr_longstr_t
        *match_key;                     /*  Match table key                  */
    </local>
    assert (subscr);
    assert (self->topics);

    /*  We scan all known topics to see which ones match our criteria        */
    regexp = ipr_regexp_new (subscr->topic_re);

    for (topic_nbr = 0; topic_nbr < self->topics->bound; topic_nbr++) {
        topic = amq_topic_array_fetch (self->topics, topic_nbr);
        assert (topic);
        if (ipr_regexp_match (regexp, topic->dest_name, NULL)) {
            /*  Topic must be defined in match table                         */
            match_key = ipr_longstr_new_str (topic->dest_name);
            match = amq_match_search (self, match_key);
            ipr_longstr_destroy (&match_key);
            assert (match);

            /*  Flag this subscription as matching                           */
            ipr_bits_set (match->bits, subscr->index);

            /*  Add a reference to the subscription                          */
            ipr_looseref_new (subscr->matches, match);
        }
    }
    ipr_regexp_destroy (&regexp);
</method>

<method name = "parse fields" template = "function">
    <doc>
    Parse the selector fields specifier and derive terms from it. We create
    a term for each field/value combination.
    </doc>
    <argument name = "subscr" type = "amq_subscr_t *" >Subscription to register</argument>
    <local>
    amq_field_list_t
        *fields;                        /*  Selector fields                  */
    amq_field_t
        *field;                         /*  Next field to examine            */
    amq_match_t
        *match;                         /*  Match item                       */
    ipr_longstr_t
        *match_key;
    </local>

    fields = amq_field_list_new (subscr->selector);
    if (fields) {
        field = amq_field_list_first (fields);
        while (field) {
            match_key = amq_match_field_value (field);
            match = amq_match_search (self, match_key);
            if (match == NULL)
                match = amq_match_new (self, match_key);
            ipr_longstr_destroy (&match_key);

            /*  Flag this subscription as matching                               */
            ipr_bits_set (match->bits, subscr->index);

            /*  Add a reference to the subscription                              */
            ipr_looseref_new (subscr->matches, match);

            field = amq_field_list_next (fields, field);
            subscr->field_count++;
        }
        amq_field_list_destroy (&fields);
    }
    else
        amq_global_set_error (AMQP_SYNTAX_ERROR, "Invalid selector field table");
</method>

<method name = "check topic" template = "function">
    <doc>
    Checks whether the specified topic name has already been seen by
    susbcribers, and if not, rebuilds a match table entry for the
    topic, for all subscribers.  This method is designed to allow the
    topic match table to be constructed dynamically as publishers use
    new topic names.
    </doc>
    <argument name = "dest name"   type = "char *">Topic destination</argument>
    <argument name = "subscr_list" type = "amq_subscr_list_t *">Current subscribers</argument>
    <local>
    amq_match_t
        *match;                         /*  Match item                       */
    amq_subscr_t
        *subscr;                        /*  Subscription object              */
    ipr_regexp_t
        *regexp;                        /*  Regular expression object        */
    ipr_longstr_t
        *match_key;
    </local>
    assert (self->topics);

    match_key = ipr_longstr_new_str (dest_name);
    if (amq_match_search (self, match_key) == NULL) {
        match = amq_match_new (self, match_key);
        amq_topic_new (self->topics, self->topics->bound, dest_name);

        /*  Recompile all subscriptions for this topic                       */
        subscr = amq_subscr_list_first (subscr_list);
        while (subscr) {
            regexp = ipr_regexp_new (subscr->topic_re);
            if (ipr_regexp_match (regexp, dest_name, NULL)) {
                /*  Flag this subscription as matching                       */
                ipr_bits_set (match->bits, subscr->index);

                /*  Add a reference to the subscription                      */
                ipr_looseref_new (subscr->matches, match);
            }
            ipr_regexp_destroy (&regexp);
            subscr = amq_subscr_list_next (subscr_list, subscr);
        }
    }
    ipr_longstr_destroy (&match_key);
</method>

<method name = "selftest" />

</class>