package ite.trace.types;

/**
 * Trigger-Mode
 * 
 * @author stefan alex
 * 
 */
public enum TriggerMode {
	pointTrigger("Point-Trigger", 0), preTrigger("Pre-Trigger", 1), centerTrigger("Center-Trigger", 2), postTrigger(
			"Post-Trigger", 3);

	private String s;

	private int id;
	
	/**
	 * 
	 * @return the modes id
	 */
	public int getId() {
		return id;
	}

	/**
	 * The Constructor.
	 * 
	 * @param s
	 *            a string-representation
	 * @param id
	 *            a id-value
	 */
	private TriggerMode(String s, int id) {
		this.s = s;
		this.id = id;
	}

	/**
	 * Returns a string-representation of the type
	 */
	public String toString() {
		return s;
	}

	/**
	 * Returns the enum-value corresponding with the id, or <code>null</code>,
	 * if none exists
	 */
	public static TriggerMode get(int i) {
		for (TriggerMode tm : TriggerMode.values())
			if (tm.id == i)
				return tm;
		return null;
	}

	/**
	 * 
	 * @return the number of enum-values
	 */
	public static int getCnt() {
		return TriggerType.values().length;
	}
}
