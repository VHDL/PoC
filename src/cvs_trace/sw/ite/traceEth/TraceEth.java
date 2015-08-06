package ite.traceEth;

import java.io.IOException;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.net.ServerSocket;
import java.net.Socket;

/**
 * Connects application to ethernet-library.
 * 
 * @author stefan alex
 * 
 */
public class TraceEth {
	public static void main(String[] args) throws IOException {
	  if(args.length<1) {
	    System.err.println("Specify absolute path to libTraceEth.so as first argument!");
	    System.exit(1);
	  }

	  System.load(args[0]);

		ServerSocket serverSocket = new ServerSocket(8889);

		final Socket socket = serverSocket.accept();

		DataInputStream is = new DataInputStream(socket.getInputStream());
		DataOutputStream os = new DataOutputStream(socket.getOutputStream());
		while (true) {
		  switch (is.readByte()) {
		  case 0: {
		    initialize();
		    // send ack
		    os.writeByte(0);
		    os.flush();
		    break;
		  }
		  case 1: {
		    String filename = is.readUTF();
		    int configLength = is.readInt();
		    byte[] config = new byte[configLength];
		    is.readFully(config);
		    initializeTraceReceiver(filename, config);
		    // send ack
		    os.writeByte(0);
		    os.flush();
		    break;
		  }
		  case 2: {
		    int messageLength = is.readInt();
		    byte[] message = new byte[messageLength];
		    is.readFully(message);
		    byte[] recvMessage = sendAndReceive(message);
		    os.writeInt(recvMessage.length);
		    os.write(recvMessage);
		    os.flush();
		    break;
		  }
		  case 3: {
		    finish();
		    // send ack
		    os.writeByte(0);
		    os.flush();
		    socket.close();
		    return;
		  }
		  case 4: {
		    flush();
		    // send ack
		    os.writeByte(0);
		    os.flush();
		    break;
		  }
		  default:
		    System.err.println("ERROR: unknown commmand!");
		    break;
		  }
		}
	}

	// //////////////
	// JNI-Functions
	// //////////////

	/**
	 * Sends a message an receives an answer
	 * 
	 * @param message
	 *            the coded message
	 * @return the answer
	 */
	private static native byte[] sendAndReceive(byte[] message);

	/**
	 * Initialize the a target-file.
	 * 
	 * @param filename
	 */
	private static native void initialize();

	/**
	 * Initialize the a target-file.
	 * 
	 * @param filename
	 */
	private static native void initializeTraceReceiver(String filename, byte[] config);


	/**
	 * Finish tracing. This means, close the file and free the memory.
	 * 
	 */
	private static native void finish();

	/**
	 * Finish tracing. This means, close the file and free the memory, but don't
	 * cancel program.
	 * 
	 */
	private static native void flush();

}
