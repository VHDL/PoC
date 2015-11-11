package ite.trace.exceptions;

/**
 * Diese Ausnahme wird von <code>BitVector</code>-Objekten geworfen, wenn es
 * Konflikte mit der eingestellten Lnge des <code>BitVector</code>s oder der
 * Parameter gibt.
 * 
 * @author Alex, Stefan
 * 
 */
public class InvalidLengthException extends Exception {

	private final int expectedLength;
	private final int length;

	private static final long serialVersionUID = 4524575989137433753L;

	/**
	 * Der Konstruktur.
	 * 
	 * @param length
	 *            die eigentliche Lnge
	 * @param expectedLength
	 *            die erwartete Lnge (die Lnge des BitVectors) oder ein
	 *            Grenzwert fr die Lnge
	 */
	public InvalidLengthException(int length, int expectedLength) {
		this.length = length;
		this.expectedLength = expectedLength;
	}

	/**
	 * 
	 * Gibt die erwartete Lnge (die Lnge des BitVectors) oder ein Grenzwert
	 * fr die Lnge zurck.
	 */
	public int getExpectedLength() {
		return expectedLength;
	}

	/**
	 * 
	 * Gibt die eigentliche Lnge zurck.
	 */
	public int getLength() {
		return length;
	}

}
