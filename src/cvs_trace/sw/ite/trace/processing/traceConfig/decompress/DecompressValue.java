package ite.trace.processing.traceConfig.decompress;

import ite.trace.types.CompressionType;
import ite.trace.util.BitVector;
import ite.trace.exceptions.InvalidLengthException;

/**
 * Decompress a given Data-Value.
 * 
 * @author stefan
 * 
 */

public class DecompressValue {

	private final CompressionType ct;

	private final int width;
	
	private BitVector lastValue;

	/**
	 * The constructor.
	 * 
	 * @param ct
	 * @param width
	 * @throws InvalidLengthException
	 *             the <code>width</code> value smaller than zero.
	 */
	public DecompressValue(final CompressionType ct, int width)
			throws InvalidLengthException {
		super();
		this.ct = ct;
		this.width = width;
		lastValue = new BitVector(width);
	}

	/**
	 * Decompress a given vector. The new vector should have the trimmed length
	 * and no fill-bits (no length-information is transmitted)
	 * 
	 * @param compressedVector
	 *            the compressed value
	 * @return the decompressed value
	 */
	public BitVector decompress(BitVector compressedVector) {

		switch (ct) { // TODO optimized ???

		case diffC: {
			
			if (compressedVector.getLength() == 0){			
				return lastValue;
			}

			if(compressedVector.getLength() == width){
				lastValue = compressedVector;				
				return compressedVector;
			}
			
			compressedVector.fill(width, compressedVector.getMSBit());
			BitVector result = compressedVector.addIngoreLastCarry(lastValue);
			lastValue = result;	
			return result;
			
		}
		case xorC: {
			
			if (compressedVector.getLength() == 0) {
				return lastValue;
			}
			BitVector result = compressedVector.concat(lastValue
					.getSubvector(compressedVector.getLength()));
			lastValue = result;
			return result;
		}
		case noneC: {
			return compressedVector;
		}
		case trimC: {
			compressedVector.fill(width, compressedVector.getMSBit());
			return compressedVector;

		}
		}

		return null;

	}

	/**
	 * 
	 * @return the type of this decompression-unit.
	 */
	public CompressionType getType() {
		return ct;
	}
}
