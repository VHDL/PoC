package ite.trace.types;

/**
 * Trigger-Combination-Operation
 * 
 * @author stefan alex
 * 
 */
public enum TriggerCombOpType {
	and("And", 0), or("Or", 1);

	private String s;

	private int id;

	/**
	 * The Constructor.
	 * 
	 * @param s
	 *            a string-representation
	 * @param id
	 *            a id-value
	 */
	private TriggerCombOpType(String s, int id) {
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
	public static TriggerCombOpType get(int i) {
		for (TriggerCombOpType tcop : TriggerCombOpType.values())
			if (tcop.id == i)
				return tcop;
		return null;
	}

	/**
	 * 
	 * @return the number of enum-values
	 */
	public static int getCnt() {
		return TracerType.values().length;
	}
}
