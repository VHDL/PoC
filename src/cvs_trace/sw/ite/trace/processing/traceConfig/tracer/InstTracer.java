package ite.trace.processing.traceConfig.tracer;

/**
 * A definition for instruction-tracer.
 * @author stefan alex
 */
import java.util.ArrayList;
import java.util.List;

import ite.trace.processing.traceConfig.Port;
import ite.trace.processing.traceConfig.Trigger;
import ite.trace.processing.traceConfig.tracerInstance.InstTracerInstance;
import ite.trace.processing.traceConfig.tracerInstance.TracerInstance;
import ite.trace.types.CompressionType;
import ite.trace.types.TSCType;
import ite.trace.exceptions.InvalidLengthException;

public class InstTracer extends Tracer {

	private final Port adrPort;

	private final Port branchPort;

	private final short counterBits;

	private final boolean history;

	private final boolean lsEncoder;

	private final short historyBytes;

	private final short priority;

	private final List<Trigger> trigger;

	/**
	 * The Constructor.
	 */
	public InstTracer(final Port adrPort, final Port branchPort,
			final short counterBits, final boolean history,
			final boolean lsEncoder, final short historyBytes,
			final short priority, final List<Trigger> trigger) {
		this.adrPort = adrPort;
		this.branchPort = branchPort;
		this.counterBits = counterBits;
		this.history = history;
		this.lsEncoder = lsEncoder;
		this.historyBytes = historyBytes;
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
	 * 
	 * @return the compression-type for the adress-port
	 */
	public CompressionType getAdrComp() {
		return adrPort.getComp();
	}

	/**
	 * 
	 * @return the the adress-port
	 */
	public Port getAdrPort() {
		return adrPort;
	}

	/**
	 * 
	 * @return <code>true</code> if the tracer uses branch-information
	 */
	public boolean isBranchInfo() {
		return branchPort != null;
	}

	/**
	 * 
	 * @return the number of bits for the instruction-counter
	 */
	public short getCounterBits() {
		return counterBits;
	}

	/**
	 * 
	 * @return <code>true</code> if the tracer uses a history-list for indirect
	 *         branches
	 */
	public boolean isHistory() {
		return history;
	}

	/**
	 * 
	 * @return <code>true</code> if the tracer uses the ls-encoder for the
	 *         history-list
	 */
	public boolean isLsEncoder() {
		return lsEncoder;
	}

	/**
	 * 
	 * @return the number of bytes for the history-list
	 */
	public short getHistoryBytes() {
		return historyBytes;
	}

	/**
	 * 
	 * @return the Port for branch informations
	 */
	public Port getBranchPort() {
		return branchPort;
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
	 * @return all ports in a list
	 */
	public List<Port> getPorts() {
		List<Port> l = new ArrayList<Port>();
		l.add(adrPort);
		return l;
	}

	/**
	 * 
	 * @return the number of times, the port is instantiated in this tracer
	 */
	protected int cntPorts(Port p) {
		if (adrPort.equals(p))
			return 1;
		return 0;
	}

	/**
	 * 
	 * @return the number of ports
	 */
	protected int cntPorts() {
		return 1;
	}

	/**
	 * 
	 * @return the type
	 */
	public TSCType getType() {
		return TSCType.instTracer;
	}

	/**
	 * 
	 * @return the number of inputs for this tracer.
	 */
	public int getInputs() {
		return adrPort.getInputs();
	}

	/**
	 * 
	 * @return the instances defined by this defintion
	 */
	public List<TracerInstance> getInstances() throws InvalidLengthException {
		List<TracerInstance> l = new ArrayList<TracerInstance>();
		for (int i = 0; i < getInputs(); i++)
			l.add(new InstTracerInstance(this, i));
		return l;
	}

}
