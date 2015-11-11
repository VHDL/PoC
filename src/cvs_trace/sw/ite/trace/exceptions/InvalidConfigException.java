package ite.trace.exceptions;
/**
 * Represents an invalid configuration-message from the tracing-system on the fpga.
 * @author stefan alex
 *
 */
public class InvalidConfigException extends Exception {

	private static final long serialVersionUID = 3643172392557372576L;

	private final int errorCode;

	/**
	 * 
	 * @return an error-code to describe the error. See <code>HelloTrace</code>-Source-Code for details.
	 */
	public int getErrorCode() {
		return errorCode;
	}

	/**
	 * The Constructor.
	 * @param errorCode
	 */
	public InvalidConfigException(int errorCode) {
		super();
		this.errorCode = errorCode;
	}

}
