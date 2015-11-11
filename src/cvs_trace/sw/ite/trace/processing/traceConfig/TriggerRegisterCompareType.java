package ite.trace.processing.traceConfig;

/**
 * Interface for compare-operations, either for one or for two registers.
 * 
 * @author stefan
 * 
 */

public interface TriggerRegisterCompareType {

	/**
	 * 
	 * @return a string-representation of the compare-operation.
	 */
	public String toString();
	
	/**
	 * 
	 * @return the types id
	 */
	public int getId();

}
