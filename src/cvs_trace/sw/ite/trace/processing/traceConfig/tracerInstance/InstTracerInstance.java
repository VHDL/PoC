package ite.trace.processing.traceConfig.tracerInstance;

import java.io.IOException;

import ite.trace.processing.traceConfig.Port;
import ite.trace.processing.traceConfig.decompress.DecompressValue;
import ite.trace.processing.traceConfig.decompress.LSDecoder;
import ite.trace.processing.traceConfig.tracer.InstTracer;
import ite.trace.types.CompressionType;
import ite.trace.util.BitVector;
import ite.trace.exceptions.InvalidLengthException;
import ite.trace.exceptions.InvalidTraceException;

/**
 * A concrete instance of an inst-tracer.
 * 
 * @author Stefan Alex
 * 
 */
public class InstTracerInstance extends TracerInstance {

	private final InstTracer definition;

	private final DecompressValue adrDecomp;

	private final int arrayLength;

	private final int bitsWoComp;

	private final int bytesWComp;

	private final int lengthBits;

	private final LSDecoder lsd;

	private BitVector[] emptyMessage;

	/**
	 * The constructor.
	 */
	public InstTracerInstance(InstTracer instTracer, int inputNo)
			throws InvalidLengthException {
		super(inputNo);
		definition = instTracer;

		arrayLength = 1 + (instTracer.isHistory() ? 1 : 0) + 1;
		
		Port p = instTracer.getAdrPort();
		if (p.getComp().equals(CompressionType.noneC)) {
			bitsWoComp = p.getWidth();
			bytesWComp = 0;
			adrDecomp = null;
			lengthBits = 0;
		} else {
			bitsWoComp = p.getWidth() % 8;
			bytesWComp = p.getWidth() / 8;
			adrDecomp = new DecompressValue(p.getComp(), bytesWComp * 8);
			lengthBits = log2ceil(bytesWComp + 1);
		}

		
		
		emptyMessage = new BitVector[arrayLength];

		if (definition.isHistory() & definition.isLsEncoder())
			lsd = new LSDecoder(definition.getHistoryBytes());
		else
			lsd = null;

	}

	/**
	 * 
	 * @return the <code>Tracer</code>, defining this instance.
	 */
	public InstTracer getDefinition() {
		return definition;
	}

	/**
	 * 
	 * @return the decompressed values for one cycles, when an action occurs.
	 *         The values are returned as an array of <code>BitVector</code>s.
	 * @throws IOException
	 * @throws InvalidTraceException
	 */
	public BitVector[] getNextFullMessage() throws IOException,
			InvalidTraceException {
		BitVector[] result = new BitVector[arrayLength];
		int compLength = 0;

		// get length
		if (!definition.getAdrPort().getComp().equals(CompressionType.noneC)) {			
			compLength = bitReader.getBitsAsInt(lengthBits) * 8;
		}

		// get history-value
		if (definition.isHistory())
			if (definition.isLsEncoder()) {
				result[2] = lsd.decompress(bitReader
						.getBitsAsBitVector(definition.getHistoryBytes() * 8));
			} else {
				result[2] = bitReader.getBitsAsBitVector(definition
						.getHistoryBytes() * 8);
				for (int i = definition.getHistoryBytes()*8-1; i >= 0; i--) {
					if (result[2].get(i)) {
						// History-Field starts now
						// output also leading bit to signal start of history sequence (highest '1')

						result[2] = result[2].getSubvector(0, i+1);
						break;
					}
				}
			}

		// get counter-value
		result[1] = bitReader
				.getBitsAsBitVector(definition.getCounterBits());
		
		// get uncompressed values
		if (bitsWoComp > 0)
			result[0] = bitReader.getBitsAsBitVector(bitsWoComp);

		// get compressed values
		
		if(bytesWComp > 0){
			if (bitsWoComp > 0) {
				result[0] = result[0].concat(adrDecomp.decompress(bitReader
						.getBitsAsBitVector(compLength)));
			} else {
				result[0] = adrDecomp.decompress(bitReader
						.getBitsAsBitVector(compLength));
			}	
		}		

		return result;

	}

	/**
	 * 
	 * @return the decompressed values for one cycles, when no action occurs.
	 *         The values are returned as an array of <code>BitVector</code>s.
	 */
	public BitVector[] getNextEmptyMessage() {
		return emptyMessage;
	}

	private int log2ceil(int value) {
		for (int i = 0; i < 31; i++) {
			if (pot2(i) >= value)
				return i;
		}
		return -1;
	}

	private int pot2(int exponent) {
		if ((exponent < 0) | (exponent > 31))
			return -1;

		int result = 1;
		for (int i = 0; i < exponent; i++) {
			result = result * 2;
		}
		return result;
	}

}
