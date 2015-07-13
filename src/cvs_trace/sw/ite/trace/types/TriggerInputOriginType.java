package ite.trace.types;

/**
 * Trigger-Input-Origin-Tyoe
 * 
 * @author stefan
 * 
 */
public enum TriggerInputOriginType {
	port("Port", 0), statisticTracer("Statistic-Tracer", 1), extern("Extern", 2);

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
	private TriggerInputOriginType(String s, int id) {
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
	public static TriggerInputOriginType get(int i) {
		for (TriggerInputOriginType tiot : TriggerInputOriginType.values())
			if (tiot.id == i)
				return tiot;
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