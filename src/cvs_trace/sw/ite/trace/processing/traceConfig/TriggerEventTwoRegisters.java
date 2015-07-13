package ite.trace.processing.traceConfig;

import ite.trace.types.TriggerTwoRegistersCompareType;
import ite.trace.util.BitVector;
import ite.trace.exceptions.InvalidLengthException;

/**
 * Trigger-Event with two registers.
 * 
 * @author stefan alex
 * 
 */
public class TriggerEventTwoRegisters extends TriggerSingleEvent {

	private BitVector reg2;

	private TriggerTwoRegistersCompareType registerCompareType;

	/**
	 * The Constructor.
	 */
	protected TriggerEventTwoRegisters(int id, Port port,
			TriggerTwoRegistersCompareType registerCompareType)
			throws InvalidLengthException {
		super(id, port);
		this.reg2 = new BitVector(port.getWidth());
		this.registerCompareType = registerCompareType;
	}

	/**
	 * Sets the compare-type of the trigger-registers.
	 * 
	 * @param triggerRegisterCompareType2
	 */
	protected void setTriggerRegisterCompareType(
			TriggerTwoRegistersCompareType registerCompareType) {
		this.registerCompareType = registerCompareType;
	}

	/**
	 * 
	 * @return the compare-type of the trigger-registers.
	 */
	protected TriggerTwoRegistersCompareType getRegisterCompareType() {
		return registerCompareType;
	}

	/**
	 * 
	 * @return the second trigger-register as <code>BitVector</code>
	 */
	protected BitVector getReg2Value() {
		return reg2;
	}

	/**
	 * Sets the value of the second trigger-register.
	 * 
	 * @param bv
	 */
	protected boolean setReg2Value(BitVector bv) {
		if(bv.getLength()!=super.getPort().getWidth())
			return false;
		
		reg2 = bv;
		return true;
	}
	
	/**
	 * 
	 * @param set all registers
	 */
	protected boolean setRegValue(BitVector bv){
		boolean result = true;
		result = result & super.setReg1Value(bv.getSubvector(0, super.getPort().getWidth()));
		result = result & setReg2Value(bv.getSubvector(super.getPort().getWidth()));
		return result;
	}

	/**
	 * Sets the compare-type of the first trigger-register.
	 */
	protected boolean setRegisterCompareType(TriggerRegisterCompareType type){
		if(type instanceof TriggerTwoRegistersCompareType){
			registerCompareType = (TriggerTwoRegistersCompareType) type;
			return true;
		} else {
			return false;
		}			 
	}
	
	/**
	 * 
	 * @return <code>true</code> if the event has two regs
	 */
	protected boolean hasTwoRegs(){
		return true;
	}
	
	/**
	 * 
	 * @return the width of the register(s)
	 */
	protected int getRegsWidths() {
		return super.getReg1Value().getLength() + reg2.getLength();
	}

	/**
	 * 
	 * @return the type of the compare-operation
	 */
	protected TriggerRegisterCompareType getCompareType() {
		return registerCompareType;
	}
}
