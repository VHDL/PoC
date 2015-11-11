package ite.trace.types;

import ite.trace.processing.traceConfig.TriggerRegisterCompareType;

/**
 * Trigger-Register-Compare-Types
 * 
 * @author stefan alex
 * 
 */
public enum TriggerOneRegisterCompareType implements TriggerRegisterCompareType {
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
	private TriggerOneRegisterCompareType(String s, int id) {
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
	public static TriggerOneRegisterCompareType get(int i) {
		for (TriggerOneRegisterCompareType tcop : TriggerOneRegisterCompareType
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
		return TriggerOneRegisterCompareType.values().length;
	}
	
	/**
	 * 
	 * @return the types id
	 */
	public int getId(){
		return id;
	}
}
