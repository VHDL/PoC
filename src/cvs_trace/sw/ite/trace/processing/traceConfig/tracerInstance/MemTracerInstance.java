package ite.trace.processing.traceConfig.tracerInstance;

import java.io.IOException;

import ite.trace.processing.traceConfig.Port;
import ite.trace.processing.traceConfig.decompress.DecompressValue;
import ite.trace.processing.traceConfig.tracer.MemTracer;
import ite.trace.types.CompressionType;
import ite.trace.util.BitVector;
import ite.trace.exceptions.InvalidLengthException;

/**
 * A concrete instance of a memory-tracer.
 * 
 * @author Stefan Alex
 * 
 */
public class MemTracerInstance extends TracerInstance{

	private final MemTracer definition;

	private final DecompressValue[] msgDecomps;

	private final int arrayLength;

	private final int[] lengthBits;
	
	private final int idBits;
	
	private final int sourceIndex;
	
	private final int rwIndex;
	
	private final int datIndex;
	
	private final int[] bitsWoComp;
	private final int[] bytesWComp;

	private BitVector[] emptyMessage;
	
	private int[] compLength;
	
	private final boolean datComp;
	
	/**
	 * The constructor.
	 */
	public MemTracerInstance(MemTracer memTracer, int inputNo)
			throws InvalidLengthException {
		super(inputNo);
		definition = memTracer;
		idBits = log2ceil(memTracer.getAdrPortCnt()+2);
		lengthBits = new int[memTracer.getAdrPortCnt()+1];
		msgDecomps = new DecompressValue[memTracer.getAdrPortCnt()+1];
		bitsWoComp = new int[memTracer.getAdrPortCnt()+1];
		bytesWComp = new int[memTracer.getAdrPortCnt()+1];
		for (int i = 0; i < memTracer.getAdrDataPorts().size(); i++) {			
			Port p = memTracer.getAdrDataPorts().get(i);
			if(p.getComp().equals(CompressionType.noneC)){
				bitsWoComp[i] = p.getWidth();
				bytesWComp[i] = 0;
			} else {
				bitsWoComp[i] = p.getWidth() % 8;
				bytesWComp[i] = p.getWidth() / 8;
				msgDecomps[i] = new DecompressValue(p.getComp(), bytesWComp[i]*8);
				lengthBits[i] = log2ceil(bytesWComp[i]+1);
			}
						
		}

		arrayLength = memTracer.getAdrPortCnt()+ 1 + 1 + (memTracer.getSourcePort() == null ? 0 : 1);		
		rwIndex = memTracer.getAdrPortCnt()+ 1;
		sourceIndex = rwIndex + 1;
		datIndex = memTracer.getAdrPortCnt();
		datComp = memTracer.getDataPort().getComp() != CompressionType.noneC;
		
		compLength = new int[1+(datComp ? 1 : 0)];
		
		emptyMessage = new BitVector[arrayLength];
		
		
	}
	
	/**
	 * 
	 * @return the <code>Tracer</code>, defining this instance.
	 */
	public MemTracer getDefinition() {
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
		
		int id = bitReader.getBitsAsInt(idBits);
		boolean cv;
		
		int id_i;
		if(id < definition.getAdrPortCnt()+1){
			id_i = id;
			cv = false;
		} else {
			id_i = id - 2;
			cv = true;
		}
		
		// get source-value
		
		if (definition.getSourcePort() != null){
			result[sourceIndex] =  bitReader.getBitsAsBitVector(definition.getSourcePort().getWidth());
		}

		// get rw-info
		
		if (id_i == definition.getAdrPortCnt()-1){
			result[rwIndex] = bitReader.getBitsAsBitVector(1);
		}			
		
		// get length

		if (!definition.getPorts().get(id_i).getComp().equals(
				CompressionType.noneC)){
			compLength[0] = bitReader.getBitsAsInt(lengthBits[id_i]) * 8;
		}
			
		
		// get additional data-length
		
		if(cv & datComp){
			compLength[1] = bitReader.getBitsAsInt(lengthBits[datIndex]) * 8;
		}
			
		
		// get uncompressed values
		if(bitsWoComp[id_i]>0)
			result[id_i] = bitReader.getBitsAsBitVector(bitsWoComp[id_i]);
		
		// get additional data-value (uncompressed)
		if(cv & bitsWoComp[datIndex]>0)
			result[datIndex] = bitReader.getBitsAsBitVector(bitsWoComp[datIndex]);

		// get compressed values
		if (definition.getPorts().get(id_i).getComp() != CompressionType.noneC)
			if (bitsWoComp[id_i] > 0){
				result[id_i] = result[id_i].concat(msgDecomps[id_i].decompress(bitReader
					.getBitsAsBitVector(compLength[0])));
			} else {
				result[id_i] = msgDecomps[id_i].decompress(bitReader
						.getBitsAsBitVector(compLength[0]));			
			}

		// get additional data-value (compressed)
		if(cv){
			if(datComp){
				if (bitsWoComp[datIndex] > 0){
					result[datIndex] = result[datIndex].concat(msgDecomps[datIndex].decompress(bitReader
						.getBitsAsBitVector(compLength[1])));
				} else {
					result[datIndex] = msgDecomps[datIndex].decompress(bitReader
							.getBitsAsBitVector(compLength[1]));
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
