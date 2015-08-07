package ite.trace.types;

/**
 * Trigger-Type
 * 
 * @author stefan alex
 * 
 */
public enum TriggerType {
	normal("Normal", 0), start("Start", 1), stop("Stop", 2);
	
	private String s;

	private int id;

	/**
	 * 
	 * @return the id
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
	private TriggerType(String s, int id) {
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
	public static TriggerType get(int i) {
		for (TriggerType tt : TriggerType.values())
			if (tt.id == i)
				return tt;
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
