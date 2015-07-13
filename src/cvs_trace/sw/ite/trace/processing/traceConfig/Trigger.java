package ite.trace.processing.traceConfig;

import ite.trace.types.TriggerMode;
import ite.trace.types.TriggerType;

/**
 * A trigger.
 * 
 * @author stefan alex
 * 
 */
public class Trigger {

	private final int id;
	
	private TriggerType type;

	private TriggerMode mode;

	private boolean events[];

	/**
	 * The Constructor.
	 */
	protected Trigger(int id, TriggerType type, TriggerMode mode, int events) {
		super();
		this.id = id;
		this.type = type;
		this.mode = mode;
		this.events = new boolean[events];
		for (int i = 0; i < this.events.length; i++)
			this.events[i] = true;
	}

	/**
	 * 
	 * @return the id
	 */
	protected int getId(){
		return id;
	}
	
	/**
	 * 
	 * @return returns the number of associated trigger-events.
	 */
	protected int getEvents() {
		return events.length;
	}

	/**
	 * 
	 * @return <code>true</code>, if a given event is enabled
	 */
	protected boolean getActiv(int i) {
		return events[i];
	}

	/**
	 * Toogle the activ-field.
	 */
	protected void toogleActiv(int i) {
		events[i] = !events[i];
	}

	/**
	 * 
	 * @return the triggers mode.
	 */
	protected TriggerMode getMode() {
		return mode;
	}

	/**
	 * Sets the triggers mode.
	 * 
	 * @param mode
	 */
	protected void setMode(TriggerMode mode) {
		this.mode = mode;
	}

	/**
	 * 
	 * @return the triggers type.
	 */
	protected TriggerType getType() {
		return type;
	}

	/**
	 * Sets the triggers type.
	 * 
	 * @param type
	 */
	protected void setType(TriggerType type) {
		this.type = type;
	}

}
