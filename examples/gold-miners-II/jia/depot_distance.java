package jia;

import jason.asSemantics.DefaultInternalAction;
import jason.asSemantics.TransitionSystem;
import jason.asSemantics.Unifier;
import jason.asSyntax.NumberTermImpl;
import jason.asSyntax.Term;
import jason.environment.grid.Location;

import java.util.logging.Level;

import arch.LocalWorldModel;
import arch.MinerArch;
import busca.Nodo;

/**
 * Internal action that computes the A* path length from the agent's
 * current position to the depot.
 *
 * Usage in AgentSpeak:
 *   jia.depot_distance(Distance)
 *
 * Returns false (fails) if the agent's position or depot is unknown,
 * or if no path exists.
 *
 * Example:
 *   jia.depot_distance(D);
 *   if (D < 5) { ... }
 */
public class depot_distance extends DefaultInternalAction {

    @Override
    public Object execute(TransitionSystem ts, Unifier un, Term[] terms) throws Exception {
        try {
            LocalWorldModel model = ((MinerArch) ts.getUserAgArch()).getModel();
            int agId = ((MinerArch) ts.getUserAgArch()).getMyId();

            Location agPos = model.getAgPos(agId);
            Location depot = model.getDepot();

            if (agPos == null || depot == null) {
                ts.getLogger().info("depot_distance: agent position or depot unknown.");
                return false;
            }

            int toX = depot.x;
            int toY = depot.y;

            Nodo solution = new Search(model, agPos, new Location(toX, toY)).search();
            if (solution != null) {
                int length = solution.getProfundidade();
                return un.unifies(terms[0], new NumberTermImpl(length));
            } else {
                ts.getLogger().info("depot_distance: No route from " + agPos + " to depot " + depot);
            }
        } catch (Throwable e) {
            ts.getLogger().log(Level.SEVERE, "jia.depot_distance error: " + e, e);
        }
        return false;
    }
}
