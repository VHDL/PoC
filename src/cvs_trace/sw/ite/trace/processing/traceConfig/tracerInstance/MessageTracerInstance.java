package ite.trace.processing.traceConfig.tracerInstance;

import java.io.IOException;

import ite.trace.processing.traceConfig.Port;
import ite.trace.processing.traceConfig.decompress.DecompressValue;
import ite.trace.processing.traceConfig.tracer.MessageTracer;
import ite.trace.types.CompressionType;
import ite.trace.util.BitVector;
import ite.trace.exceptions.InvalidLengthException;

/**
 * A concrete instance of a message-tracer.
 * 
 * @author Stefan Alex
 * 
 */
public class MessageTracerInstance extends TracerInstance {

	private final MessageTracer definition;

	private final DecompressValue[] msgDecomps;

	private final int arrayLength;

	private final int[] bitsWoComp;
	private final int[] bytesWComp;

	private final int[] lengthBits;
	
	private BitVector[] emptyMessage;

	/**
	 * The constructor.
	 */
	public MessageTracerInstance(MessageTracer messageTracer, int inputNo)
			throws InvalidLengthException {
		super(inputNo);

		definition = messageTracer;

		arrayLength = messageTracer.getPorts().size();
		
		bitsWoComp = new int[arrayLength];
		bytesWComp = new int[arrayLength];
		lengthBits = new int[arrayLength];				
		msgDecomps = new DecompressValue[arrayLength];
		for (int i = 0; i < arrayLength; i++) {
			Port p = messageTracer.getPorts().get(i);
			if(p.getComp().equals(CompressionType.noneC)){
				bitsWoComp[i] = p.getWidth();
				bytesWComp[i] = 0;
			} else {
				bitsWoComp[i] = p.getWidth() % 8;
				bytesWComp[i] = p.getWidth() / 8;
				lengthBits[i] = log2ceil(bytesWComp[i]+1);			
				msgDecomps[i] = new DecompressValue(p.getComp(), bytesWComp[i]*8);
			}
			

		}
		emptyMessage = new BitVector[arrayLength];

	}

	/**
	 * 
	 * @return the <code>Tracer</code>, defining this instance.
	 */
	public MessageTracer getDefinition() {
		return definition;
	}

	/**
	 * 
	 * @return the decompressed values for one cycles, when an action occurs.
	 *         The values are returned as an array of <code>BitVector</code>s.
	 * @throws IOException
	 */
	public BitVector[] getNextFullMessage() throws IOException {
		BitVector[] result = new BitVector[arrayLength];

		int[] compLength = new int[arrayLength];

		// get length
		for (int i = 0; i < definition.getPorts().size(); i++) {
			if (!definition.getPorts().get(i).getComp().equals(
					CompressionType.noneC)){				
				compLength[i] = bitReader.getBitsAsInt(lengthBits[i]) * 8;
			}
		}		

		// get uncompressed values
		for (int i = 0; i < definition.getPorts().size(); i++) {
			if(bitsWoComp[i]>0)
				result[i] = bitReader.getBitsAsBitVector(bitsWoComp[i]);
		}

		// get compressed values
		for (int i = 0; i < definition.getPorts().size(); i++) {
			if (bytesWComp[i] > 0){
				if (bitsWoComp[i] > 0){
					result[i] = result[i].concat(msgDecomps[i].decompress(bitReader
						.getBitsAsBitVector(compLength[i])));
				} else {
					result[i] = msgDecomps[i].decompress(bitReader
							.getBitsAsBitVector(compLength[i]));
				}
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
