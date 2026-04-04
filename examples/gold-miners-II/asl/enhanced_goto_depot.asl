// enhanced_goto_depot.asl
// go to depot, drop gold, step away, repeat

/* goto_depot -- walk there, drop everything, move off */

+!goto_depot
  :  depot(_,DX,DY) & carrying_gold(N) & N > 0
  <- .print("Going to depot to deliver ",N," gold(s).");
     // tell team about golds i saw but didnt go for
     .findall(gold(X,Y), gold(X,Y)[source(self)], L);
     !announce_not_handled_golds(L);
     !pos(DX,DY);
     !ensure_drop(0);
     !leave_depot;
     !!choose_goal.

// Fallback: cannot reach depot
-!goto_depot
  <- .print("Cant reach depot, re-deciding.");
     !!choose_goal.


/* announce golds i never went for, so teammates know about them */

+!announce_not_handled_golds([]).
+!announce_not_handled_golds([G|R])
   :  not committed_to(G,_,_) & not announced(G)
   <- .print("Telling team about ",G);
      .broadcast(tell,G);
      +announced(G);
      !announce_not_handled_golds(R).
+!announce_not_handled_golds([_|R])
   <- !announce_not_handled_golds(R).


/* ensure_drop: keep dropping until we have 0 gold
   drops at depot dont actually fail from fatigue but we
   retry just in case */

max_drop_retries(6).

// done
+!ensure_drop(N) : carrying_gold(0).

// still have gold, drop it
+!ensure_drop(N)
  :  max_drop_retries(Max) & N < Max &
     depot(_,X,Y) & pos(X,Y,_)
  <- do(drop);
     !ensure_drop(N+1).

// shouldnt happen but just in case
+!ensure_drop(N)
  :  max_drop_retries(Max) & N >= Max
  <- .print("Couldnt drop after ",N," tries??").


/* leave_depot: move off the depot so teammates can use it
   try to bump enemies first, otherwise pick a free adjacent cell */

+!leave_depot : pos(X,Y,_) & cell(X+1,Y,enemy) <- do(right).
+!leave_depot : pos(X,Y,_) & cell(X-1,Y,enemy) <- do(left).
+!leave_depot : pos(X,Y,_) & cell(X,Y-1,enemy) <- do(up).
+!leave_depot : pos(X,Y,_) & cell(X,Y+1,enemy) <- do(down).

+!leave_depot : pos(X,Y,_) & not cell(X+1,Y,ally) & not jia.obstacle(X+1,Y) <- do(right).
+!leave_depot : pos(X,Y,_) & not cell(X-1,Y,ally) & not jia.obstacle(X-1,Y) <- do(left).
+!leave_depot : pos(X,Y,_) & not cell(X,Y-1,ally) & not jia.obstacle(X,Y-1) <- do(up).
+!leave_depot : pos(X,Y,_) & not cell(X,Y+1,ally) & not jia.obstacle(X,Y+1) <- do(down).

+!leave_depot. // cant move, whatever
