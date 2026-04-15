// enhanced_miner.asl
// main agent file -- goal selection, gold evaluation, coordination

{ include("enhanced_moving.asl") }
{ include("enhanced_search.asl") }
{ include("search_quadrant.asl") }
{ include("enhanced_fetch_gold.asl") }
{ include("enhanced_goto_depot.asl") }
{ include("allocation_protocol.asl") }

/* registered functions */

{ register_function("carrying.gold",0,"carrying_gold") }
{ register_function("jia.path_length",4,"jia.path_length") }

/* initial beliefs */

free.
my_capacity(3).
search_gold_strategy(near_unvisited).


/* sim start -- triggered on step 0 */

+pos(_,_,0)
  <- ?gsize(S,_,_);
     .print("Starting simulation ", S);
     !inform_gsize_to_leader(S);
     !choose_goal.

+!inform_gsize_to_leader(S) : .my_name(eminer1)
   <- ?depot(S,DX,DY);
      .send(enhanced_leader,tell,depot(S,DX,DY));
      ?gsize(S,W,H);
      .send(enhanced_leader,tell,gsize(S,W,H)).
+!inform_gsize_to_leader(_).


/* choose_goal -- decides what to do next
   priority: time pressure > fetch gold > go depot > explore */

// running out of time, head to depot
@cg_time[atomic]
+!choose_goal
  :  carrying_gold(NG) & NG > 0 &
     pos(AgX,AgY,Step) &
     depot(_,DX,DY) &
     steps(_,TotalSteps) &
     jia.path_length(AgX,AgY,DX,DY,DepotDist) &
     jia.add_fatigue(DepotDist, NG, FatigueDist) &
     AvailableSteps = TotalSteps - Step &
     AvailableSteps < FatigueDist * 1.15
  <- .print("Low on time (",AvailableSteps," left, need ~",FatigueDist,"), going to depot.");
     !change_to_goto_depot.

// found reachable gold and have space for it
@cg_fetch[atomic]
+!choose_goal
 :  container_has_space &
    .findall(gold(X,Y),gold(X,Y),LG) &
    evaluate_golds(LG,LD) &
    .length(LD) > 0 &
    .min(LD,d(D,NewG,_)) &
    worthwhile(NewG)
 <- .print("Gold options: ",LD,". Next gold: ",NewG);
    !change_to_fetch(NewG).

// carrying gold but nothing good nearby, just go drop it off
+!choose_goal
 :  carrying_gold(NG) & NG > 0
 <- !change_to_goto_depot.

// nothing else to do, go explore
+!choose_goal
 <- !change_to_search.


/* goal switching helpers */

// -- change_to_goto_depot --
+!change_to_goto_depot
  :  .desire(goto_depot)
  <- .print("Already heading to depot.").
+!change_to_goto_depot
  :  .desire(fetch_gold(G))
  <- .drop_desire(fetch_gold(G));
     !change_to_goto_depot.
+!change_to_goto_depot
  <- -free;
     !!goto_depot.

// -- change_to_fetch --
+!change_to_fetch(G)
  :  .desire(fetch_gold(G)).      // already fetching this gold
+!change_to_fetch(G)
  :  .desire(goto_depot)
  <- .drop_desire(goto_depot);
     !change_to_fetch(G).
+!change_to_fetch(G)
  :  .desire(fetch_gold(OtherG))
  <- .drop_desire(fetch_gold(OtherG));
     !change_to_fetch(G).
+!change_to_fetch(G)
  <- -free;
     !!fetch_gold(G).

// -- change_to_search --
+!change_to_search
  :  search_gold_strategy(S)
  <- .print("New goal: search gold (",S,").");
     -free;
     +free;
     .drop_all_desires;
     !!search_gold(S).


/* gold evaluation -- rank golds by distance + fatigue cost */

evaluate_golds([],[]) :- true.
evaluate_golds([gold(GX,GY)|R],[d(U,gold(GX,GY),Annot)|RD])
  :- evaluate_gold(gold(GX,GY),U,Annot) &
     evaluate_golds(R,RD).
evaluate_golds([_|R],RD)
  :- evaluate_golds(R,RD).

evaluate_gold(gold(X,Y),Utility,Annot)
  :- pos(AgX,AgY,_) &
     jia.path_length(AgX,AgY,X,Y,D) &
     jia.add_fatigue(D,Utility) &
     check_commit(gold(X,Y),Utility,Annot).

// gold on the same cell, always worth considering
check_commit(_,0,in_my_place)   :- true.
// no one else going for this gold
check_commit(G,_,not_committed) :- not committed_to(G,_,_).
// someone committed but im closer
check_commit(gold(X,Y),MyD,committed_by(Ag,at(OtX,OtY),far(OtD)))
  :- committed_to(gold(X,Y),_,Ag) &
     jia.ag_pos(Ag,OtX,OtY) &
     jia.path_length(OtX,OtY,X,Y,OtD) &
     MyD < OtD.


/* worthwhile check -- make sure we can get gold AND make it back to depot in time */

// not carrying anything yet, any gold is fine
worthwhile(gold(_,_)) :-
     carrying_gold(0).

// already have some gold, check if theres enough time to grab more and still get back
worthwhile(gold(GX,GY)) :-
     carrying_gold(NG) & NG > 0 &
     pos(AgX,AgY,Step) &
     depot(_,DX,DY) &
     steps(_,TotalSteps) &
     AvailableSteps = TotalSteps - Step &
     // distance to gold with current load
     jia.add_fatigue(jia.path_length(AgX,AgY,GX,GY), NG,   CostToGold) &
     // distance from gold to depot with one more gold
     jia.add_fatigue(jia.path_length(GX,GY,DX,DY),   NG+1, CostToDepot) &
     // check we have time (with some buffer)
     AvailableSteps > (CostToGold + CostToDepot) * 1.02.


/* reacting to gold/empty percepts */

// saw new gold and have space -- remember it and reconsider goals
@pcell_gold[atomic]
+cell(X,Y,gold)
  :  container_has_space &
     not gold(X,Y)
  <- .print("Gold perceived: ",gold(X,Y));
     +gold(X,Y);
     !choose_goal.

// saw gold but im full, tell the others
+cell(X,Y,gold)
  :  not container_has_space &
     not gold(X,Y) &
     not committed(gold(X,Y),_,_)
  <- +gold(X,Y);
     +announced(gold(X,Y));
     .print("No space. Announcing ",gold(X,Y)," to team.");
     .broadcast(tell,gold(X,Y)).

// gold right under me while heading to depot, might as well grab it
@pcell_opportunistic[atomic]
+cell(X,Y,gold)
  :  pos(X,Y,_) &
     container_has_space &
     gold(X,Y) &
     .desire(goto_depot)
  <- .print("Grabbing gold at ",X,",",Y," on the way.");
     do(pick).

// gold i knew about is gone, someone else got it
+cell(X,Y,empty)
  :  gold(X,Y) &
     not .desire(fetch_gold(gold(X,Y)))
  <- !remove(gold(X,Y));
     .print("Gold at ",X,",",Y," gone. Telling team.");
     .broadcast(tell,picked(gold(X,Y))).


/* simulation end -- clean up */

+end_of_simulation(S,R)
  <- .drop_all_desires;
     !remove(gold(_,_));
     .abolish(picked(_));
     -+search_gold_strategy(near_unvisited);
     .abolish(quadrant(_,_,_,_));
     .abolish(last_checked(_,_));
     -+free;
     .print("-- END ",S,": ",R).


/* misc helpers */

+!remove(gold(X,Y))
  <- .abolish(gold(X,Y));
     .abolish(committed_to(gold(X,Y),_,_));
     .abolish(picked(gold(X,Y)));
     .abolish(announced(gold(X,Y)));
     .abolish(allocated(gold(X,Y),_)).

// stuck for too long, force restart
@rl[atomic]
+restart
  <- .print("Stuck, restarting.");
     .drop_all_desires;
     !choose_goal.
