package ite.trace.processing.traceConfig.tracerInstance;

import java.io.IOException;

import ite.trace.processing.traceConfig.tracer.Tracer;
import ite.trace.util.BitReader;
import ite.trace.util.BitVector;
import ite.trace.exceptions.InvalidTraceException;

/**
 * A concrete instance of a tracer.
 * 
 * @author Stefan Alex
 * 
 */
public abstract class TracerInstance {

	protected BitReader bitReader;

	private final int inputNo;

	/**
	 * The constructor.
	 */
	protected TracerInstance(int inputNo) {
		this.inputNo = inputNo;
	}

	/**
	 * Sets a <code>BitReader</code> to the tracer for decompression.
	 * 
	 * @param bitReader
	 */
	public void setBitReader(BitReader bitReader) {
		this.bitReader = bitReader;
	}

	/**
	 * 
	 * @return the input-number of this instance in the given definition
	 */
	public int getInputNo() {
		return inputNo;
	}

	/**
	 * 
	 * @return the <code>Tracer</code>, defining this instance.
	 */
	public abstract Tracer getDefinition();

	/**
	 * 
	 * @return the decompressed values for one cycles, when an action occurs.
	 *         The values are returned as an array of <code>BitVector</code>s.
	 * @throws IOException
	 * @throws InvalidTraceException
	 */
	public abstract BitVector[] getNextFullMessage() throws IOException,
			InvalidTraceException;

	/**
	 * 
	 * @return the decompressed values for one cycles, when no action occurs.
	 *         The values are returned as an array of <code>BitVector</code>s.
	 */
	public abstract BitVector[] getNextEmptyMessage();

}
