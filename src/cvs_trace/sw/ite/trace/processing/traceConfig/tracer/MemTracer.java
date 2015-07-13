package ite.trace.processing.traceConfig.tracer;

/**
 *  A definition for memory-tracer.
 *   @author stefan alex
 */

import java.util.ArrayList;
import java.util.List;

import ite.trace.processing.traceConfig.Port;
import ite.trace.processing.traceConfig.Trigger;
import ite.trace.processing.traceConfig.tracerInstance.MemTracerInstance;
import ite.trace.processing.traceConfig.tracerInstance.TracerInstance;
import ite.trace.types.TSCType;
import ite.trace.exceptions.InvalidLengthException;

public class MemTracer extends Tracer {

	private final List<Port> adrPorts;

	private final Port dataPort;

	private final Port rwPort;
	
	private final Port sourcePort;

	private final boolean collectVal;

	private final short priority;

	private final List<Trigger> trigger;

	/**
	 * The Constructor.
	 * 
	 */
	public MemTracer(final List<Port> adrPorts,
			final Port dataPort, final Port rwPort,
			final Port sourcePort, final boolean collectVal,
			final short priority, final List<Trigger> trigger){
		this.adrPorts = adrPorts;
		this.dataPort = dataPort;
		this.rwPort = rwPort;
		this.sourcePort = sourcePort;
		this.collectVal = collectVal;
		this.priority = priority;
		this.trigger = trigger;
	}
	
	/**
	 * 
	 * @return a list of associated trigger
	 */
	public List<Trigger> getTrigger(){
		return trigger;
	}

	/**
	 * 
	 * @return the adress-ports
	 */
	public List<Port> getAdrPorts() {
		return adrPorts;
	}

	/**
	 * 
	 * @return the number of adress-ports
	 */
	public int getAdrPortCnt() {
		return adrPorts.size();
	}

	/**
	 * 
	 * @return the data-port
	 */
	public Port getDataPort() {
		return dataPort;
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
	 * @return the the source-port
	 */
	public Port getSourcePort() {
		return sourcePort;
	}
	
	/**
	 * 
	 * @return the the rw-port
	 */
	public Port getRwPort() {
		return rwPort;
	}

	/**
	 * 
	 * @return <code>true</code> if the tracer collect values before it sends
	 *         it.
	 */
	public boolean isCollectVal() {
		return collectVal;
	}

	/**
	 * 
	 * @return all ports in a list. Duplicates are possible.
	 */
	public List<Port> getPorts() {
		List<Port> l = new ArrayList<Port>();
		for (Port p : adrPorts)
			l.add(p);
		l.add(dataPort);
		l.add(sourcePort);
		l.add(rwPort);
		return l;
	}
	
	/**
	 * 
	 * @return the adress- and data-ports
	 */
	public List<Port> getAdrDataPorts() {
		List<Port> l = new ArrayList<Port>();
		for (Port p : adrPorts)
			l.add(p);
		l.add(dataPort);
		return l;
	}	

	/**
	 * 
	 * @return the number of times, the port is instantiated in this tracer
	 */
	protected int cntPorts(Port p) {
		int sum = 0;
		for (Port p2 : adrPorts)
			if (p2.equals(p))
				sum++;
		if (dataPort.equals(p))
			sum++;
		if (sourcePort.equals(p))
			sum++;
		return sum;

	}

	/**
	 * 
	 * @return the number of ports
	 */
	protected int cntPorts() {
		return adrPorts.size() + 3;
	}

	/**
	 * 
	 * @return the type
	 */
	public TSCType getType() {
		return TSCType.memTracer;
	}
	
	/**
	 * 
	 * @return the number of inputs for this tracer.
	 */
	public int getInputs() {
		return dataPort.getInputs();
	}
	

	/**
	 * 
	 * @return the instances defined by this defintion
	 */
	public List<TracerInstance> getInstances() throws InvalidLengthException {
		List<TracerInstance> l = new ArrayList<TracerInstance>();
		for (int i = 0; i < getInputs(); i++)
			l.add(new MemTracerInstance(this, i));
		return l;
	}
	
}
