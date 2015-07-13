package ite.trace.processing.traceConfig.tracer;

/**
 *  A definition for message-tracer.
 *   @author stefan alex
 */

import java.util.ArrayList;
import java.util.List;

import ite.trace.processing.traceConfig.Port;
import ite.trace.processing.traceConfig.Trigger;
import ite.trace.processing.traceConfig.tracerInstance.MessageTracerInstance;
import ite.trace.processing.traceConfig.tracerInstance.TracerInstance;
import ite.trace.types.TSCType;
import ite.trace.exceptions.InvalidLengthException;

public class MessageTracer extends Tracer {

	private final List<Port> msgPorts;

	private final short priority;

	private final List<Trigger> trigger;

	/**
	 * 
	 * The Constructor.
	 * 
	 * @throws IllegalArgumentException
	 *             if the two arrays have a different length
	 */
	public MessageTracer(final List<Port> msgPorts, final short priority,
			final List<Trigger> trigger) throws IllegalArgumentException,
			InvalidLengthException {

		this.msgPorts = msgPorts;
		this.priority = priority;
		this.trigger = trigger;

	}

	/**
	 * 
	 * @return a list of associated trigger
	 */
	public List<Trigger> getTrigger() {
		return trigger;
	}
	
	/**
	 * @return the message-port
	 */
	public List<Port> getMsgPorts() {
		return msgPorts;
	}

	/**
	 * 
	 * @return the number of message-ports
	 */
	public int getMsgPortCnt() {
		return msgPorts.size();
	}

	/**
	 * 
	 * @return the tracers priority
	 */
	public short getPriority() {
		return priority;
	}

	/**
	 * 
	 * @return all ports in a list. Duplicates are possible.
	 */
	public List<Port> getPorts() {
		return getMsgPorts();
	}

	/**
	 * 
	 * @return the number of times, the port is instantiated in this tracer
	 */
	protected int cntPorts(Port p) {
		int sum = 0;
		for (Port p2 : msgPorts)
			if (p2.equals(p))
				sum++;
		return sum;

	}

	/**
	 * 
	 * @return the number of ports
	 */
	protected int cntPorts() {
		return msgPorts.size();
	}

	/**
	 * 
	 * @return the type
	 */
	public TSCType getType() {
		return TSCType.messageTracer;
	}

	/**
	 * 
	 * @return the number of inputs for this tracer.
	 */
	public int getInputs() {
		return msgPorts.get(0).getInputs();
	}

	/**
	 * 
	 * @return the instances defined by this defintion
	 */
	public List<TracerInstance> getInstances() throws InvalidLengthException {
		List<TracerInstance> l = new ArrayList<TracerInstance>();
		for (int i = 0; i < getInputs(); i++)
			l.add(new MessageTracerInstance(this, i));
		return l;
	}
}
