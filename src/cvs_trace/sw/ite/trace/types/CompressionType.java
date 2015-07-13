package ite.trace.types;

/**
 * Compression-Types
 * 
 * @author stefan alex
 * 
 */
public enum CompressionType {
	noneC("none", 0), diffC("diff", 1), xorC("xor", 2), trimC("trim", 3);

	private int id;

	private String s;

	/**
	 * The Constructor.
	 * 
	 * @param s
	 *            a string-representation
	 * @param id
	 *            a id-value
	 */
	private CompressionType(String s, int id) {
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
	public static CompressionType get(int i) {
		for (CompressionType ct : CompressionType.values())
			if (ct.id == i)
				return ct;
		return null;
	}

	/**
	 * 
	 * @return the number of enum-values
	 */
	public static int getCnt() {
		return CompressionType.values().length;
	}
}
