package ite.trace.exceptions;

/**
 * Die Ausnahme wird von <code>BitVector</code>-Klassen geworfen, wenn eine
 * Eingabe eines oder mehrerer Bits ungltig ist.
 * 
 * @author Alex, Stefan
 * 
 */
public class InvalidBitRepresentationException extends Exception {

	private static final long serialVersionUID = -5914785179409805765L;

	private final String value;

	/**
	 * Der Konstruktor.
	 * 
	 * @param value
	 *            der Wert, der nicht einer binren/hexadezimalen Darstellung
	 *            gengt
	 */
	public InvalidBitRepresentationException(String value) {
		this.value = value;
	}

	/**
	 * 
	 * Gibt den ungltige Wert zurck.
	 */
	public String getValue() {
		return value;
	}

}
