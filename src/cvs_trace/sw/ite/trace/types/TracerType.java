package ite.trace.types;

/**
 * Tracer-Types
 * 
 * @author stefan alex
 * 
 */
public enum TracerType {
	instTracer("Inst-Tracer",0), memTracer("Mem-Tracer",1), messageTracer(
			"Message-Tracer",2), statisticTracer("Statistic-Tracer",3);

	private String s;
	private int id;

	/**
	 * The Constructor.
	 * 
	 * @param s
	 *            a string-representation
	 * @param id a id-value
	 */
	private TracerType(String s, int id) {
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
	public static TracerType get(int i) {
		for (TracerType tt : TracerType.values())
			if (tt.id == i)
				return tt;
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
