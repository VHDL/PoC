package ite.trace.processing.traceConfig;

/**
 * A representation for a statistic-component.
 * 
 * @author Stefan Alex
 */

public class Statistic {

	private final Port port;

	/**
	 * 
	 * @return the port of the tracer
	 */
	protected Port getPort() {
		return port;
	}

	/**
	 * The Constructor.
	 * @param port
	 */
	protected Statistic(final Port port) {
		super();
		this.port = port;
	}

}
