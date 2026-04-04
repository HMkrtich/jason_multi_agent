// enhanced_search.asl
// exploration -- go to least-visited cells, re-evaluate after each one

/* search by going to nearest least-visited cell */

+!search_gold(near_unvisited)
   :  pos(X,Y,_) & free &
      jia.near_least_visited(X,Y,ToX,ToY)
   <- !pos(ToX,ToY);
      // arrived, re-check if something better came up
      !!choose_goal.

// nothing found to explore, wait a bit and try again
+!search_gold(near_unvisited) : free
   <- .wait(200);
      !!search_gold(near_unvisited).

// Failure recovery
-!search_gold(near_unvisited)
   <- !!choose_goal.

/* stop exploring when gold is found */

@lfg[atomic]
-free
  :  .desire(search_gold(_))
  <- .print("Stopping search, got something to do.");
     .drop_desire(search_gold(_)).
