package ite.trace.processing;

import java.io.IOException;

import ite.trace.util.BitVector;

/**
 * Formats and writes trace-infomation to a defined destination.
 * 
 * @author Stefan Alex
 * 
 */
public interface TraceWriter {

	/**
	 * Finishs writing.
	 * @throws IOException
	 */
	public void close() throws IOException;

	/**
	 * Writes trace-information of one cycle.
	 * 
	 * @param values
	 *            the values per tracer of this cycle.
	 * @throws IllegalArgumentException
	 *             when the number of value-array doesn't match the number of
	 *             tracer.
	 * @throws IOException
	 */
	public void write(BitVector[][] values) throws IllegalArgumentException, IOException;

	/**
	 * Go to i cycles after the current one.
	 * 
	 * @param i
	 */
	public void nextCycle(int i);

}
