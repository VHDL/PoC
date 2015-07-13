package ite.trace.processing.traceConfig.decompress;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import ite.trace.processing.traceConfig.tracerInstance.TracerInstance;
import ite.trace.util.BitReader;
import ite.trace.util.BitVector;
import ite.trace.exceptions.InvalidLengthException;
import ite.trace.exceptions.InvalidTraceException;

/**
 * Decodes trace and select next tracer-instance.
 * 
 * The tracer-instances can have an coding with variable length.
 * 
 * @author Stefan Alex
 * 
 */
public class VariableCodingTracerProvider implements TracerProvider {

	private final BitReader br;
	private final Map<String, TracerInstance> coding;

	/**
	 * The constructor.
	 * 
	 * @param br
	 *            the current trace
	 * @param tracerInstances
	 *            the tracers-instances in coding-order (contains doubling
	 *            through multiple inputs).
	 */
	public VariableCodingTracerProvider(BitReader br,
			List<TracerInstance> tracerInstances) {
		this.br = br;

		coding = new HashMap<String, TracerInstance>();

		try {

			List<List<TracerInstance>> prioritySorting = sortTracerPriority(tracerInstances);

			for (int i = 0; i < prioritySorting.size(); i++) {

				String startCoding = "";

				// startCoding

				if (i == 0) {
					// lowest priority
					int higherPriorities = prioritySorting.size() - 1;
					for (int j = 0; j < higherPriorities; j++)
						startCoding += "0";
				} else {
					// other (higher) priority
					int higherPriorities = prioritySorting.size() - i - 1;
					for (int j = 0; j < higherPriorities; j++)
						startCoding += "0";
					startCoding = "1" + startCoding;
				}

				// singleCoding
				int singleCnt = prioritySorting.get(i).size();
				if (singleCnt > 1) {
					BitVector singleCoding = new BitVector(log2ceil(singleCnt));
					for (TracerInstance t : prioritySorting.get(i)){
						coding
								.put(singleCoding.getBinaryString()
										+ startCoding, t);
						singleCoding = singleCoding.increment();
					}						
					
				} else {
					coding.put(startCoding, prioritySorting.get(i).get(0));
				}
			}

		} catch (InvalidLengthException ile) {
			ile.printStackTrace();
		}

		
	}

	/**
	 * 
	 * @return the next tracer-instance, or <code>null</null>, if none exists.
	 * @throws InvalidTraceException
	 * @throws IOException
	 */
	public TracerInstance getNextTracerInstance() throws InvalidTraceException,
			IOException {		
		String codingString = br.getBitsAsString(1);
		while (!coding.containsKey(codingString)) {
			codingString = br.getBitsAsString(1) + codingString;			
			if (codingString.length() > 100){
				throw new InvalidTraceException(0);
			}
				
		}
		return coding.get(codingString);
	}

	/**
	 * Returns a list of lists. All tracers in the same list have the same
	 * priority. The lists with a higher index have the higher priority.
	 * 
	 */
	private List<List<TracerInstance>> sortTracerPriority(
			List<TracerInstance> tracerInstances) {
		List<TracerInstance> tracerInstances_i = new ArrayList<TracerInstance>();
		for(TracerInstance t : tracerInstances)
			tracerInstances_i.add(t);
		List<List<TracerInstance>> result = new ArrayList<List<TracerInstance>>();

		while (!tracerInstances_i.isEmpty()) {
			List<TracerInstance> currentList = new ArrayList<TracerInstance>();

			int minPriority = Integer.MAX_VALUE;

			for (TracerInstance t : tracerInstances_i) {
				if (t.getDefinition().getPriority() < minPriority) {
					minPriority = t.getDefinition().getPriority();
					currentList.clear();
					currentList.add(t);
				} else {
					if (t.getDefinition().getPriority() == minPriority) {
						currentList.add(t);
					}
				}
			}

			for (TracerInstance t : currentList) {
				tracerInstances_i.remove(t);
			}
			result.add(currentList);
		}
		
		return result;

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
