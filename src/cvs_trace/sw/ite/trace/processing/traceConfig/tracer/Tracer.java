package ite.trace.processing.traceConfig.tracer;

import java.util.List;

import ite.trace.processing.traceConfig.Port;
import ite.trace.processing.traceConfig.tracerInstance.TracerInstance;
import ite.trace.exceptions.InvalidLengthException;

/**
 * A tracer.
 * 
 * @author stefan alex
 * 
 */
public abstract class Tracer {

	/**
	 * Returns a <code>String</code>, with <code>width</code> zeros.
	 * 
	 * @param width
	 * @return
	 */
	protected String zerosAsString(short width) {
		String result = "";
		for (int i = 0; i < width; i++)
			result = result + "0";
		return result;
	}

	/**
	 * 
	 * @return the tracers priority
	 */
	public abstract short getPriority();

	/**
	 * 
	 * @return the number of inputs for this tracer.
	 */
	public abstract int getInputs();

	/**
	 * 
	 * @return the instances defined by this defintion
	 */
	public abstract List<TracerInstance> getInstances()
			throws InvalidLengthException;
	
	/**
	 * 
	 * @return all ports in a list. Duplicates are possible.
	 */
	public abstract List<Port> getPorts();
	

}
