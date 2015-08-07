package ite.trace.processing.traceConfig.decompress;

import ite.trace.util.BitVector;
import ite.trace.exceptions.InvalidLengthException;
import ite.trace.exceptions.InvalidTraceException;

/**
 * LSDecoder for history-field-decompression.
 * 
 * @author Stefan Alex
 * 
 */
public class LSDecoder {


	private final int messageTypeIndex;

	private final int lastValIndex;

	private final int longChartStart;

	/**
	 * The constructor.
	 */
	public LSDecoder(int bytes) {
		messageTypeIndex = bytes * 8 - 1;
		lastValIndex = messageTypeIndex - 1;
		longChartStart = bytes * 8 - 2 + 1;
	}

	public BitVector decompress(BitVector value) throws InvalidTraceException {
		
		if (!value.get(messageTypeIndex)) {
			// Short Chart Message
			for (int i = lastValIndex; i >= 0; i--) {
				if (value.get(i)) {
					// History-Field starts now
					return value.getSubvector(0, i);
				}
			}
			throw new InvalidTraceException(2);
		} else {
			// Long Chart Message
			BitVector result = null;
			try{
				result = new BitVector(longChartStart, value
						.get(lastValIndex));
				for (int i = 0; i < value.getSubvector(0, lastValIndex).getInt(); i++) {
					result.append(value.get(lastValIndex));
				}	
			} catch (InvalidLengthException ile){
				ile.printStackTrace();
			}
			return result;
		}

	}
}