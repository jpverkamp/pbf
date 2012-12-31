pbf
===

A parallel variant of brainf**k, adding four new instructions: & ~ ! ?

Full list of instructions
-------------------------

Original instructions:

    < Move the tape pointer to the left
    > Move the tape pointer to the right 
    + Increment the current cell
    - Decrement the current cell
    . Output the value in the current cell
    , Read a value into the current cell
    [ If the current cell is 0, skip past the matching ]
    ] If the current cell is not 0, skip back to the matching [

Debugging instructions:

    # Print the current contents of the tape

Parallel instructions:

    & Spawn a new thread, the current cell is 0 in the parent and 1 in the child
    ~ Kill the current thread
    ! Send a ping on the channel specified by the current cell
    ? Wait for a ping on the channel specified by the current cell

Todo
----

Add some way to actually communicate information other than timing between threads. 

Turing Completeness
-------------------

Since pbf is a strict superset of bf, it is also Turing complete. 

Examples
========

split-cat.pbf
-------------
    read from stdin while alternating adding and subtracting one

    &[     spawn thread 1 (echo +1)
     +     set cell 0 to 1 (to ID the thread)
     >>+   set cell 2 to 1
     <,    read into cell 1
     [     while not EOF:
      +.    add 1 and echo
      >+!   set cell 2 to 2 and send a ping on 2
      -?    set cell 2 to 1 and wait for a ping on 1
      <,    read into cell 1
     ]
     ~     kill this thread
    ]
    
    &[     spawn thread 2
     ++    set cell 0 to 2 (to ID the thread)
     >>++? set cell 2 to 2 and wait for a ping on 2
     <,    read into cell 1
     [     while not EOF:
      -.    sub 1 and echo
      >-!   set cell 2 to 1 and send a ping on 1
      +?    set cell 2 to 2 and wait for a ping on 2
      <,    read into cell 1
     ]
     ~     kill this thread
    ]

hello.pbf
---------
    the goal:
     thread 0 outputs 'H' and sends 1
     on 1 thread 1 outputs 'ello' and sends 2
     on 2 thread 2 outputs ' ' and sends 3
     on 3 thread 0 outputs 'W' and sends 4
     on 4 thread 1 outputs 'orld' and sends 5
     on 5 thread 2 outputs bang
    
    &[-         spawn thread 0 (for H and W)
     >          go to cell 1
     +++++++++  set cell 1 to 9
     [          loop while cell 1 is not 0:
      <++++++++  add 8 to cell 0
      >-         subtract 1 from cell 1
     ]
     <.         output cell 0 (9 * 8 = 72 = 'H')
     >+!        send a ping on 1
     ++         set cell 2 to 3
     [          loop while cell 1 is not 0:
      <+++++     add 5 to cell 0
      >-         subtract 1 from cell 1
     ]
     +++?      wait for a ping on 3
     <.        output cell 0 (72 + 3 * 5 = 87 = 'W')
     >+!        send a ping on 4
     ~          kill this thread
    ]
    
    &[-         spawn thread 1 (for 'ello' and 'orld')
     >+++++
      +++++     add 10 to cell 1
     [          while cell 1 is not 0:
      <+++++
       +++++    add 10 to cell 0
      >-        subtract 1 from cell 1
     ]
     <+         add 1 to cell 0
     >+?        wait for a ping on 1
     <.         output cell 0 (10 * 10 + 1 = 101 = 'e')
     ++++++..   add 7 to cell 0 (for 108 = 'l') and output twice
     +++.       add 3 to cell 0 (for 111 = 'o') and output
     >+!        send a ping on 2
     ++?        wait for a ping on 4
     <.         output cell 0 ('o')
     +++.       add 3 and output (114 = 'r')
     ------.    subtract 6 and output (108 = 'l')
     --------.  subtract 8 and output (100 = 'd')
     >+!        send a ping on 5
     ~          kill this thread
    ]
    
    &[-         spawn thread 2 (for ' ' and bang)
     >++++      set cell 1 to 4
     [          while cell 1 is not 0:
      <++++++++  add 8 to cell 0
      >-         subtract 1 from cell 1
     ]
     ++?        wait for a ping on 2
     <.         output cell 0 (4 * 8 = 32 = ' ')
     >+!        send a ping on 3
     <+         add 1 to cell 0
     >++?       wait for a ping on 5
     <.         output cell 0 (32 + 1 = 33 = '!')
     ~          kill this thread
    ]
