package ite.trace.processing.traceConfig;

import ite.trace.util.BitVector;
import ite.trace.exceptions.InvalidLengthException;

/**
 * Single-Event for trigger-logic
 * 
 * @author stefan alex
 * 
 */
public abstract class TriggerSingleEvent {

	private final Port port;

	private BitVector reg1;

	private final int id;

	/**
	 * The Constructor.
	 * 
	 */
	protected TriggerSingleEvent(final int id, final Port port)
			throws InvalidLengthException {
		super();
		this.id = id;
		this.port = port;
		this.reg1 = new BitVector(port.getWidth());
	}

	/**
	 * 
	 * @return the id
	 */
	protected int getId(){
		return id;
	}
	
	/**
	 * 
	 * @return the port of the associated trigger-input.
	 */
	protected Port getPort() {
		return port;
	}

	/**
	 * Sets the value of the first trigger-register.
	 * 
	 * @param bv
	 */
	protected boolean setReg1Value(BitVector bv) {
		if(bv.getLength() != port.getWidth())
			return false;
		
		reg1 = bv;
		return true;
	}

	/**
	 * 
	 * @param set
	 *            all registers
	 */
	protected abstract boolean setRegValue(BitVector bv);

	/**
	 * Sets the compare-type of the first trigger-register.
	 */
	protected abstract boolean setRegisterCompareType(TriggerRegisterCompareType type);
	
	/**
	 * 
	 * @return the first trigger-register as <code>BitVector</code>
	 */
	protected BitVector getReg1Value() {
		return reg1;
	}

	/**
	 * 
	 * @return the width of the register(s)
	 */
	protected abstract int getRegsWidths();
	
	/**
	 * 
	 * @return <code>true</code> if the event has two regs
	 */
	protected abstract boolean hasTwoRegs();

	/**
	 * 
	 * @return the type of the compare-operation
	 */
	protected abstract TriggerRegisterCompareType getRegisterCompareType();

}
