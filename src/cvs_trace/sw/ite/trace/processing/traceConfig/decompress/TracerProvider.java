package ite.trace.processing.traceConfig.decompress;

import java.io.IOException;

import ite.trace.processing.traceConfig.tracerInstance.TracerInstance;
import ite.trace.exceptions.InvalidTraceException;

/**
 * Decodes trace and select next tracer-instance.
 * 
 * @author Stefan Alex
 * 
 */
public interface TracerProvider {

	/**
	 * 
	 * @return the next tracer-instance, or <code>null</null>, if none exists.
	 * @throws InvalidTraceException
	 * @throws IOException
	 */
	public TracerInstance getNextTracerInstance() throws InvalidTraceException,
			IOException;

}
