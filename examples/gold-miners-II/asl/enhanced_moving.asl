// enhanced_moving.asl
// movement plans -- uses A* for direction each step
// handles fatigue (actions can silently fail) by relying on
// the frozen-detection in MinerArch which adds +restart after
// 6 cycles without moving

last_dir(null).


/* next_step: get A* direction and move one cell */

+!next_step(X,Y)
   :  pos(AgX,AgY,_)
   <- jia.direction(AgX, AgY, X, Y, D);
      -+last_dir(D);
      do(D).

+!next_step(X,Y) : not pos(_,_,_)   // dont have position yet
   <- !next_step(X,Y).

// failed, try again
-!next_step(X,Y)
   <- .print("next_step to ", X,"x",Y," failed, retrying.");
      -+last_dir(null);
      !next_step(X,Y).


/* pos/spos: go to a specific cell, one step at a time
   percepts only update between cycles so each next_step does
   one action, then we recurse to pick up the new position */

+!pos(X,Y)
  :  .desire(spos(OX,OY))
  <- .current_intention(I);
     .print("** Conflict: trying to go to ",X,",",Y,
            " while !spos to ",OX,",",OY," runs in intention ",I);
     .fail.

+!pos(X,Y)
  <- jia.set_target(X,Y);
     !spos(X,Y).

// Arrived at destination
+!spos(X,Y) : pos(X,Y,_).

// target turned out to be an obstacle (maybe teammate told us)
+!spos(X,Y) : jia.obstacle(X,Y)
  <- .print("Can't go to ",X,",",Y," -- obstacle. Bailing.");
     .fail.

// Normal movement: one step towards (X,Y), then recurse
+!spos(X,Y) : not jia.obstacle(X,Y)
  <- !next_step(X,Y);
     !spos(X,Y).
