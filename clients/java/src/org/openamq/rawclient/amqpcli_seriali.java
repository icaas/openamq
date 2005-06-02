package org.openamq.rawclient;//  Object used by amqpcli_serial
//  Generated by LIBERO 2.4 on  1 Jun, 2005, 12:58.
//  Schema file used: lrschema.jav.


abstract public class amqpcli_seriali
{
    //- Variables used by dialog interpreter --------------------------------

    private static int
        _LR_event,                  //  Event for state transition
        _LR_state,                  //  Current dialog state
        _LR_savest,                 //  Saved dialog state
        _LR_index;                  //  Index of methods function

    public static int
        the_next_event,             //  Next event from module
        the_exception_event;        //  Exception event from module

    private static boolean
        exception_raised;           //  TRUE if exception raised


    //- Symbolic constants and event numbers --------------------------------

    private static int
        _LR_STOP            = 0xFFFF,
        _LR_NULL_EVENT      = -2;
    public static int
        _LR_STATE_after_init = 0,
        _LR_STATE_connection_initiation = 1,
        _LR_STATE_hand_shake = 2,
        _LR_STATE_test      = 3,
        _LR_STATE_connection_close = 4,
        _LR_STATE_defaults  = 5,
        _LR_defaults_state  = 5,
        connection_challenge_event = 0,
        connection_tune_event = 1,
        do_tests_event      = 2,
        done_event          = 3,
        error_event         = 4,
        exception_event     = 5,
        ok_event            = 6,
        send_connection_initiation_event = 7,
        timeout_event       = 8,
        terminate_event     = -1;

    //- Static areas --------------------------------------------------------

    private static int _LR_nextst [][] = {
        { 0,0,0,0,0,0,1,0,0 },
        { 0,0,0,0,0,0,0,2,0 },
        { 2,3,0,0,0,0,0,0,0 },
        { 0,0,4,0,0,0,0,0,0 },
        { 0,0,0,4,0,0,0,0,0 },
        { 0,0,0,0,0,5,0,0,5 }
    };

    private static int _LR_action [][] = {
        { 0,0,0,0,2,0,1,0,0 },
        { 0,0,0,0,0,0,0,3,0 },
        { 4,5,0,0,0,0,0,0,0 },
        { 0,0,6,0,0,0,0,0,0 },
        { 0,0,0,7,0,0,0,0,0 },
        { 0,0,0,0,0,2,0,0,8 }
    };

    private static int _LR_vector [][] = {
        {0},
        {0,_LR_STOP},
        {1,2,_LR_STOP},
        {3,_LR_STOP},
        {4,_LR_STOP},
        {5,6,_LR_STOP},
        {7,2,_LR_STOP},
        {8,2,_LR_STOP},
        {9,_LR_STOP}
    };

    abstract public void initialise_the_program ();
    abstract public void get_external_event ();
    abstract public void setup ();
    abstract public void forced_shutdown ();
    abstract public void terminate_the_program ();
    abstract public void send_connection_initiation ();
    abstract public void face_connection_challenge ();
    abstract public void negotiate_connection_tune ();
    abstract public void send_connection_open ();
    abstract public void do_tests ();
    abstract public void shutdown ();
    abstract public void handle_timeout ();

    //- Dialog interpreter starts here --------------------------------------

    public int execute ()
    {
        int
            feedback = 0,
            index,
            next_module;

        _LR_state = 0;                  //  First state is always zero
        initialise_the_program ();
        while (the_next_event != terminate_event)
          {
            _LR_event = the_next_event;
            if (_LR_event >= 9 || _LR_event < 0)
              {
                String buffer;
                buffer  = "State " + _LR_state + " - event " + _LR_event;
                buffer += " is out of range";
                System.out.println (buffer);
                break;
              }
            _LR_savest = _LR_state;
            _LR_index  = _LR_action [_LR_state][_LR_event];
            //  If no action for this event, try the defaults state
            if (_LR_index == 0)
              {
                _LR_state = _LR_defaults_state;
                _LR_index = _LR_action [_LR_state][_LR_event];
              }
            if (_LR_index == 0)
              {
                String buffer;
                buffer  = "State " + _LR_state + " - event " + _LR_event;
                buffer += " is not accepted";
                System.out.println (buffer);
                break;
              }
            the_next_event          = _LR_NULL_EVENT;
            the_exception_event     = _LR_NULL_EVENT;
            exception_raised        = false;
            next_module             = 0;

            for (;;)
              {
                index = _LR_vector [_LR_index][next_module];
                if ((index == _LR_STOP)
                    || (exception_raised))
                break;
                switch (index)
                  {
                    case 0: setup (); break;
                    case 1: forced_shutdown (); break;
                    case 2: terminate_the_program (); break;
                    case 3: send_connection_initiation (); break;
                    case 4: face_connection_challenge (); break;
                    case 5: negotiate_connection_tune (); break;
                    case 6: send_connection_open (); break;
                    case 7: the_next_event = terminate_event; break; //do_tests (); break;
                    case 8: shutdown (); break;
                    case 9: handle_timeout (); break;
                  }
                  next_module++;
              }
            if (exception_raised)
              {
                if (the_exception_event != _LR_NULL_EVENT)
                    _LR_event = the_exception_event;
                the_next_event = _LR_event;
              }
            else
                _LR_state = _LR_nextst [_LR_state][_LR_event];

            if (_LR_state == _LR_defaults_state)
                _LR_state = _LR_savest;
            if (the_next_event == _LR_NULL_EVENT)
              {
                get_external_event ();
                if (the_next_event == _LR_NULL_EVENT)
                  {
                    String buffer;
                    buffer  = "No event set after event " + _LR_event;
                    buffer += " in state " + _LR_state;
                    System.out.println (buffer);
                    break;
                  }
              }
          }
        return (feedback);
    }

    //- Standard dialog routines --------------------------------------------
    public void raise_exception (int event)
    {
        exception_raised = true;
        if (event >= 0)
            the_exception_event = event;
    }

}
