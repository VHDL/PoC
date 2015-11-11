package ite.trace.types;

/**
 * Trigger-Register-Compare-Types
 * 
 * @author stefan alex
 * 
 */
public enum TriggerRegisterCompareType {
	greaterThan("Greater", 0), equal("Equal", 1), smallerThan("Smaller", 2);

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
	private TriggerRegisterCompareType(String s, int id) {
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
	public static TriggerRegisterCompareType get(int i) {
		for (TriggerRegisterCompareType tcop : TriggerRegisterCompareType
				.values())
			if (tcop.id == i)
				return tcop;
		return null;
	}

	/**
	 * 
	 * @return the number of enum-values
	 */
	public static int getCnt() {
		return TriggerRegisterCompareType.values().length;
	}
}
