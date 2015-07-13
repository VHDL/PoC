package ite.trace.exceptions;

/**
 * The trace-file contains invalid information.
 * 
 * @author Stefan Alex
 * 
 */
public class InvalidTraceException extends Exception {

	private static final long serialVersionUID = 5854585383971071149L;

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
	public InvalidTraceException(int errorCode) {
		super();
		this.errorCode = errorCode;
	}
	
}
