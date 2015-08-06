package ite.trace.processing.traceConfig;

import ite.trace.types.TriggerOneRegisterCompareType;
import ite.trace.util.BitVector;
import ite.trace.exceptions.InvalidLengthException;

/**
 * Trigger-Event with one register.
 * 
 * @author stefan alex
 * 
 */
public class TriggerEventOneRegister extends TriggerSingleEvent {

	private TriggerOneRegisterCompareType registerCompareType;

	/**
	 * The Constructor.
	 */
	protected TriggerEventOneRegister(int id, Port port,
			TriggerOneRegisterCompareType registerCompareType)
			throws InvalidLengthException {
		super(id, port);
		this.registerCompareType = registerCompareType;
	}

	/**
	 * 
	 * @return <code>true</code> if the event has two regs
	 */
	protected boolean hasTwoRegs(){
		return false;
	}
	
	/**
	 * 
	 * @return the width of the register(s)
	 */
	protected int getRegsWidths() {
		return super.getReg1Value().getLength();
	}
	
	/**
	 * 
	 * @param set all registers
	 */
	protected boolean setRegValue(BitVector bv){
		return super.setReg1Value(bv.getSubvector(0, super.getPort().getWidth()));
	}

	/**
	 * 
	 * @return the compare-type of the first trigger-register.
	 */
	protected TriggerOneRegisterCompareType getregisterCompareType() {
		return registerCompareType;
	}

	/**
	 * Sets the compare-type of the first trigger-register.
	 * 
	 */
	protected boolean setRegisterCompareType(TriggerRegisterCompareType type){
		if(type instanceof TriggerOneRegisterCompareType){
			registerCompareType = (TriggerOneRegisterCompareType) type;
			return true;
		} else {
			return false;
		}			 
	}
	/**
	 * 
	 * @return the type of the compare-operation
	 */
	protected TriggerRegisterCompareType getRegisterCompareType() {
		return registerCompareType;
	}

}
