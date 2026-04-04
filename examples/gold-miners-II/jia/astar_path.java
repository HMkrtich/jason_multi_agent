package jia;

import jason.asSemantics.DefaultInternalAction;
import jason.asSemantics.TransitionSystem;
import jason.asSemantics.Unifier;
import jason.asSyntax.ASSyntax;
import jason.asSyntax.ListTerm;
import jason.asSyntax.ListTermImpl;
import jason.asSyntax.NumberTerm;
import jason.asSyntax.NumberTermImpl;
import jason.asSyntax.Structure;
import jason.asSyntax.Term;
import jason.environment.grid.Location;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.logging.Level;

import arch.LocalWorldModel;
import arch.MinerArch;
import busca.Estado;
import busca.Nodo;

/**
 * A* pathfinding internal action.
 * jia.astar_path(FromX, FromY, ToX, ToY, Path, Length)
 * returns the path as a list of pos(X,Y) and its length.
 * fails if no path exists.
 */
public class astar_path extends DefaultInternalAction {

    @Override
    public Object execute(TransitionSystem ts, Unifier un, Term[] terms) throws Exception {
        try {
            LocalWorldModel model = ((MinerArch) ts.getUserAgArch()).getModel();

            int fromX = (int) ((NumberTerm) terms[0]).solve();
            int fromY = (int) ((NumberTerm) terms[1]).solve();
            int toX   = (int) ((NumberTerm) terms[2]).solve();
            int toY   = (int) ((NumberTerm) terms[3]).solve();

            if (!model.inGrid(toX, toY)) {
                ts.getLogger().info("astar_path: destination (" + toX + "," + toY + ") is out of grid.");
                return false;
            }

            // nudge destination if its on an obstacle
            while (!model.isFreeOfObstacle(toX, toY) && toX > 0) toX--;
            while (!model.isFreeOfObstacle(toX, toY) && toX < model.getWidth()) toX++;

            Location from = new Location(fromX, fromY);
            Location to   = new Location(toX, toY);

            // run A*
            Nodo solution = new Search(model, from, to).search();
            if (solution == null) {
                ts.getLogger().info("astar_path: No route from " + from + " to " + to);
                return false;
            }

            // walk back from solution node to build the path
            List<Location> pathLocs = new ArrayList<>();
            Nodo current = solution;
            while (current != null) {
                GridState state = (GridState) current.getEstado();
                pathLocs.add(state.pos);
                current = current.getPai();
            }
            // reverse so its start->goal
            Collections.reverse(pathLocs);

            // build AgentSpeak list, skip the starting position
            ListTerm pathList = new ListTermImpl();
            ListTerm tail = pathList;
            for (int i = 1; i < pathLocs.size(); i++) { // skip index 0 (start)
                Location loc = pathLocs.get(i);
                Structure posTerm = ASSyntax.createStructure("pos",
                        new NumberTermImpl(loc.x),
                        new NumberTermImpl(loc.y));
                tail = tail.append(posTerm);
            }

            int length = solution.getProfundidade(); // depth = number of steps

            return un.unifies(terms[4], pathList) &&
                   un.unifies(terms[5], new NumberTermImpl(length));

        } catch (Throwable e) {
            ts.getLogger().log(Level.SEVERE, "jia.astar_path error: " + e, e);
        }
        return false;
    }
}
