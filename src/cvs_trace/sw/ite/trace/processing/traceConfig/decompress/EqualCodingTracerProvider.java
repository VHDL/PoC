package ite.trace.processing.traceConfig.decompress;

import java.io.IOException;
import java.util.List;

import ite.trace.processing.traceConfig.tracerInstance.TracerInstance;
import ite.trace.util.BitReader;
import ite.trace.exceptions.InvalidTraceException;

/**
 * Decodes trace and select next tracer-instance.
 * 
 * All tracers have an coding with equal length.
 * 
 * @author Stefan Alex
 * 
 */
public class EqualCodingTracerProvider implements TracerProvider {

	private final BitReader br;
	private final List<TracerInstance> tracerInstances;
	private final int codingLength;

	/**
	 * The constructor.
	 * 
	 * @param br
	 *            the current trace
	 * @param tracerInstances
	 *            the tracers-instances in coding-order
	 */
	public EqualCodingTracerProvider(BitReader br,
			List<TracerInstance> tracerInstances) {
		this.br = br;
		this.tracerInstances = tracerInstances;
		this.codingLength = log2ceil(tracerInstances.size());
	}

	/**
	 * 
	 * @return the next tracer-instance, or <code>null</null>, if none exists.
	 * @throws InvalidTraceException
	 * @throws IOException
	 */
	public TracerInstance getNextTracerInstance() throws InvalidTraceException,
			IOException {
		
		if (codingLength == 0)
			return tracerInstances.get(0);
		
		int value = br.getBitsAsInt(codingLength);
		if (value == -1)
			return null;
		if (value >= tracerInstances.size())
			throw new InvalidTraceException(0);
		return tracerInstances.get(value);
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
