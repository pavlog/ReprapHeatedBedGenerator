import java.util.Map;


boolean record;

int h=400;//height of PCB in mm
int w=400;//width of PCB in mm
int heatWidth=380; //width of heated section
int heatHeight=380; //height of heated section
float linewidth=1.8;

; //width of traces in mm - increase this to decrease resistance, and vice versa
float powerLineWidth= (w - heatWidth)/2;  // width of power line traces in mm
float traceSpacing = 1;
float powerLineTraceSpacing = 2;
float voltage = 24.0f; //supply voltage. used to calculate current and power draw
int resistorPads = 5;

boolean thermistor = true;   // set true to include thermistor wires
float thermistorLineWidth = 0.8;  // thermistor wire width
float thermistorLineTraceSpacing = 0.8; // thermistor wire spacing
float thermistorConnect = 3;  // size of border thermistor connect
// define center region dimensions
float thermistorRegionW = 6; // width of center thermistor region
float thermistorRegionH = 5; // height of center thermistor region
// or set smd package size of the thermistor used
//String thermistorSMDPackage = null;
//String thermistorSMDPackage = "0402";
// String thermistorSMDPackage = "0603";
// String thermistorSMDPackage = "0805";
String thermistorSMDPackage = "1206";

int viewPadding=100; //extra pixels for the view in Processing, to keep it clean. Probably leave this at 100


float copperWeight = 1; //oz/sqft. used for calculating resistance and power/current draw
float totalDistance=0; //this is used to calculate the distance of the traces. leave at zero.
float totalDistancePower = 0; //this is used to calculate the distance of the traces. leave at zero.

HashMap<String, float[]> smdPackageDimensions = new HashMap<String, float[]>();

XML xml;
String wirePath = "";
int pathCount = 1;

void SETTINGS() {
  size(w+viewPadding, h+viewPadding, P3D);
  smooth();
}
void setup() {
  initSMDPackages();
  smooth();


  xml = new XML("svg");
  xml.setString("width", w + "mm");
  xml.setString("height", h + "mm");
  xml.setString("viewBox", "0 0 " + w + " " + h);
  xml.setString("version", "1.1");

  translate(viewPadding/2, viewPadding/2);
  beginShape();
  makeWire(0, 0, w, 0);
  makeWire(w, 0, w, h);
  makeWire(w, h, 0, h);
  makeWire(0, h, 0, 0);
  endShape(); 

  
  noLoop();
} 


void makeWire(float X1, float Y1, float X2, float Y2)
{
  vertex(X1, h-Y1); //Processing and Eagle have inverted vertical axes, so we flip the view in processing in the Y direction
  vertex(X2, h-Y2); 
}


float addWire(float X1, float Y1, float X2, float Y2, float xOffset)
{
  vertex(X1 + xOffset, Y1); //Processing and Eagle have inverted vertical axes, so we flip the view in processing in the Y direction
  vertex(X2 + xOffset, Y2);
  //String xmlString = "<wire x1=\""+X1+"\" y1=\""+Y1+"\" x2=\""+X2+"\" y2=\""+Y2+"\" width=\""+linewidth+"\" layer=\""+layer+"\"/>";
  // println(xmlString);
  if (wirePath == "") {
    wirePath = "M " + (X1 + xOffset) + " " + Y1;
  }
  wirePath = wirePath + " L " + (X2 + xOffset) + " " + Y2;

  return sqrt((X2-X1)*(X2-X1)+(Y2-Y1)*(Y2-Y1));
}


void addPath(int id, String def, float lineWidth, XML xml) {
  addPath(id, def, lineWidth, "black", xml);  
}

void addPath(int id, String def, float lineWidth, String lineColor, XML xml) {
    XML wire = new XML("path");
  wire.setInt("id", id);
  wire.setString("d", def);
  wire.setString("fill", "none");
  wire.setFloat("stroke-width", lineWidth);
  wire.setString("stroke", lineColor);

  xml.addChild(wire);
}

void resetWirePath() {
  wirePath = "";
}


void draw() {
  
  int numberOfPads = resistorPads;
    
  translate(viewPadding/2, viewPadding/2);
  if (thermistor) {
    float w2 = w/2 - powerLineWidth;
    float hw2 = heatWidth/2 - powerLineWidth;
    drawSingle(w2, h, hw2, heatHeight, powerLineWidth/2);
    float[] y12 = drawSingle(w2, h, hw2, heatHeight, w/2 + powerLineWidth/2);
    drawPowerLineConnect(y12);
    drawThermistor();
    numberOfPads = resistorPads * 2;
  } else {
    drawSingle(w, h, heatWidth, heatHeight, 0);
  }


  println((totalDistance)+" mm of wire");
  println((totalDistancePower)+" mm of power line wire");
  
  // we have numberOfPads parallel resistors
  // Rboard = Rpad / numberOfPads
  float distancePerSegment = totalDistance / numberOfPads;
  float resistancePerSegment = 0.000017f*totalDistance/(linewidth*copperWeight*0.035f)*(1 + (0.0039*(100 - 25)));//resistance at 100C

  float resistance = resistancePerSegment / numberOfPads;  

  float resistancePowerLine = 0.000017f*totalDistancePower/(powerLineWidth*copperWeight*0.035f)*(1 + (0.0039*(100 - 25)));//resistance at 100C
  //via http://circuitcalculator.com/wordpress/2006/01/24/trace-resistance-calculator/

  println(resistance+" ohm resistance");
  println(resistancePowerLine+" ohm resistance power line");
  float current = voltage/(resistance + resistancePowerLine);
  println(current+" Amps drawn at "+voltage+" Volts");
  println(voltage*current+" watts drawn");


  PrintWriter output = createWriter( "heatbed.svg" );

  output.print(xml.toString());
  output.close();
}





float[] drawSingle(float w, float h, float heatWidth, float heatHeight, float xOffset) {

  float ox=(w-heatWidth)/2;
  float oy=(h-heatHeight)/2;


  // resistor traces
  strokeWeight(linewidth);
  noFill();
  beginShape(LINES);
  float xMin = ox + powerLineTraceSpacing + linewidth/2;
  float xMax = ox + heatWidth - powerLineTraceSpacing - linewidth/2;
  float yMin = oy + powerLineTraceSpacing + linewidth/2;
  float yMax = oy + heatHeight - linewidth/2;
  float areaH = yMax - yMin + 2*linewidth/2;
  int maxTraces = int(areaH / (linewidth + traceSpacing));
  int tracesPerPad = maxTraces / resistorPads;

  if (tracesPerPad % 2 == 0) {
    tracesPerPad = tracesPerPad - 1;
  }

  println("creating " + resistorPads + " pads with " + tracesPerPad + " traces");


  float y = yMin;
  float powerLineY1 = 0;
  float powerLineY2 = 0;

  for (int pad = 0; pad < resistorPads; pad++) {
    if (pad == resistorPads - 1) {
      powerLineY1 = y + linewidth/2;
    }

    for (int trace = 0; trace < tracesPerPad; trace++) {
      float x = xMin;
      boolean last = false;

      if (trace == 0) {
        x = ox - powerLineWidth/2;
      } else if (trace == tracesPerPad - 1) {
        last = true;
      }

      if (trace % 2 == 0) {
        if (last) {
          totalDistance += addWire(x, y, ox + heatWidth + powerLineWidth/2, y, xOffset);
        } else {
          totalDistance += addWire(x, y, xMax, y, xOffset);
          totalDistance += addWire(xMax, y, xMax, y + traceSpacing + 2 * linewidth/2, xOffset);
        }
      } else {
        if (last) {
          totalDistance += addWire(ox + powerLineWidth/2, y, x, y, xOffset);
        } else {
          totalDistance += addWire(xMax, y, x, y, xOffset);
          totalDistance += addWire(x, y, x, y + traceSpacing + 2 * linewidth/2, xOffset);
        }
      }

      y += traceSpacing + 2 * linewidth/2;
    } 
    addPath(pathCount++, wirePath, linewidth, xml);
    resetWirePath();
  }
  endShape();

  powerLineY2 = y - ( traceSpacing + 2 * linewidth/2)  + linewidth/2;

  strokeWeight(powerLineWidth);
  noFill();
  beginShape(LINES);

  // power lines

  totalDistancePower += addWire(ox + heatWidth/2 - powerLineTraceSpacing, oy - powerLineWidth/2, ox - powerLineWidth/2, oy - powerLineWidth/2, xOffset);
  totalDistancePower += addWire(ox - powerLineWidth/2, oy - powerLineWidth/2, ox - powerLineWidth/2, powerLineY1, xOffset);
  addPath(pathCount++, wirePath, powerLineWidth, xml);
  resetWirePath();

  totalDistancePower += addWire(ox + heatWidth/2 + powerLineTraceSpacing, oy - powerLineWidth/2, ox + heatWidth + powerLineWidth/2, oy - powerLineWidth/2, xOffset);
  totalDistancePower += addWire(ox + heatWidth + powerLineWidth/2, oy - powerLineWidth/2, ox + heatWidth + powerLineWidth/2, powerLineY2, xOffset);
  addPath(pathCount++, wirePath, powerLineWidth, xml);
  resetWirePath();

  endShape(); 

  float[] answer = new float[2];
  answer[0] = powerLineY1;
  answer[1] = powerLineY2;

  return answer;
}

void drawPowerLineConnect(float[] y) {
  float ox=(w-heatWidth)/2;
  float oy=(h-heatHeight)/2;

  strokeWeight(powerLineWidth);
  noFill();
  beginShape(LINES);

  // power lines

  totalDistancePower += addWire(ox - powerLineWidth/2, y[0] - 0.1, ox - powerLineWidth/2, y[1] + powerLineTraceSpacing + powerLineWidth/2, 0);
  totalDistancePower += addWire(ox - powerLineWidth/2, y[1] + powerLineTraceSpacing + powerLineWidth/2, ox + heatWidth + powerLineWidth/2, y[1] + powerLineTraceSpacing + powerLineWidth/2, 0);
  totalDistancePower += addWire(ox + heatWidth + powerLineWidth/2, y[1] + powerLineTraceSpacing + powerLineWidth/2, ox + heatWidth + powerLineWidth/2, y[1] - powerLineTraceSpacing - 0.0001, 0);
  addPath(pathCount++, wirePath, powerLineWidth, xml);
  resetWirePath();
  strokeWeight(powerLineWidth*2);
  addWire(w/2,oy - powerLineWidth/2, w/2, y[1], 0);
  addPath(pathCount++, wirePath, powerLineWidth * 2, xml);
  resetWirePath();

  endShape();
}

void drawThermistor() {
   if (thermistorSMDPackage == null) {
     drawThermistorRegion();
   } else {
     drawThermistorSMD();
   } 
}
  
void drawThermistorRegion() {  
    color stroke = #FFFFFF; 
    noFill();
    beginShape(LINES);
    stroke(stroke);
    // thermistor region
    float sideA = powerLineTraceSpacing * 2 + thermistorRegionW;
    float sideB = powerLineTraceSpacing * 2 + thermistorRegionH;
    rectMode(CENTER);
    strokeWeight(sideA);
    addWire(w/2, h/2 + sideB/2, w/2, h/2 - sideB/2, 0);
    addPath(pathCount++, wirePath, sideA, "white", xml);
    resetWirePath();
    
    
    float width = powerLineTraceSpacing + thermistorLineWidth + thermistorLineTraceSpacing + thermistorLineWidth + powerLineTraceSpacing;

    strokeWeight(thermistorConnect + powerLineTraceSpacing);
    addWire(w/2 - width/2 - thermistorConnect, 1 + powerLineTraceSpacing/2, w/2 + width/2 + thermistorConnect,1 + powerLineTraceSpacing/2,0);
    addPath(pathCount++, wirePath, thermistorConnect + powerLineTraceSpacing, "white", xml);
    resetWirePath();

    
    strokeWeight(width);
    addWire(w/2, h/2, w/2,0,0);
    addPath(pathCount++, wirePath, width, "white", xml);
    resetWirePath();
    
    strokeWeight(thermistorLineWidth);
    stroke(0);
    addWire(w/2 - thermistorLineTraceSpacing/2 - thermistorLineWidth/2, h/2, w/2 - thermistorLineTraceSpacing/2 - thermistorLineWidth/2,0,0);
    addPath(pathCount++, wirePath, thermistorLineWidth, "black", xml);
    resetWirePath();
    addWire(w/2 + thermistorLineTraceSpacing/2 + thermistorLineWidth/2, h/2, w/2 + thermistorLineTraceSpacing/2 + thermistorLineWidth/2,0,0);
    addPath(pathCount++, wirePath, thermistorLineWidth, "black", xml);
    resetWirePath();
    
    strokeWeight(thermistorRegionH);
    addWire(w/2 - thermistorRegionW/2, h/2, w/2 - thermistorLineTraceSpacing/2, h/2, 0);
    addPath(pathCount++, wirePath, thermistorRegionH, "black", xml);
    resetWirePath();

    addWire(w/2 + thermistorRegionW/2, h/2, w/2 + thermistorLineTraceSpacing/2, h/2, 0);
    addPath(pathCount++, wirePath, thermistorRegionH, "black", xml);
    resetWirePath();

    strokeWeight(thermistorConnect);
    addWire(w/2 - thermistorLineTraceSpacing/2 - thermistorConnect, thermistorConnect/2, w/2 - thermistorLineTraceSpacing/2, thermistorConnect/2, 0);
    addPath(pathCount++, wirePath, thermistorConnect, "black", xml);
    resetWirePath();

    addWire(w/2 + thermistorLineTraceSpacing/2 + thermistorConnect, thermistorConnect/2, w/2 + thermistorLineTraceSpacing/2, thermistorConnect/2, 0);
    addPath(pathCount++, wirePath, thermistorConnect, "black", xml);
    resetWirePath();
    
    endShape();
}


void drawThermistorSMD() {
   float[] dimensions = smdPackageDimensions.get(thermistorSMDPackage);
   
   if (dimensions == null) {
     println("----- UNKNOWN smd package " + thermistorSMDPackage + " - no thermistor wiring generated");
   }
  
  float a = dimensions[0];
  float b = dimensions[1];
  float c = dimensions[2];
  
    color white = #FFFFFF;
    color black = #000000; 
    noFill();
    beginShape(LINES);
    stroke(white);
    // thermistor region
    float sideA = powerLineTraceSpacing * 2 + a;
    float sideC = powerLineTraceSpacing * 2 + c;
    rectMode(CENTER);
    strokeWeight(sideC);
    addWire(w/2, h/2 + sideA/2, w/2, h/2 - sideA/2 - powerLineTraceSpacing, 0);
    addPath(pathCount++, wirePath, sideC, "white", xml);
    resetWirePath();

    stroke(black);
    strokeWeight(a);
    addWire(w/2 - c/2, h/2, w/2 - c/2 + b, h/2,0);
    addPath(pathCount++, wirePath, a, "black", xml);
    resetWirePath();

    addWire(w/2 + c/2, h/2, w/2 + c/2 - b, h/2,0);
    addPath(pathCount++, wirePath, a, "black", xml);
    resetWirePath();

    
    float width = powerLineTraceSpacing + thermistorLineWidth + thermistorLineTraceSpacing + thermistorLineWidth + powerLineTraceSpacing;

    stroke(white);
    strokeWeight(thermistorConnect + powerLineTraceSpacing);
    addWire(w/2 - width/2 - thermistorConnect, 1 + powerLineTraceSpacing/2, w/2 + width/2 + thermistorConnect,1 + powerLineTraceSpacing/2,0);
    addPath(pathCount++, wirePath, thermistorConnect + powerLineTraceSpacing, "white", xml);
    resetWirePath();

    strokeWeight(width);
    addWire(w/2, h/2 - sideA/2 + 0.1, w/2,0,0);
    addPath(pathCount++, wirePath, width, "white", xml);
    resetWirePath();
    
    strokeWeight(thermistorLineWidth);
    stroke(black);
    addWire(w/2 - thermistorLineTraceSpacing/2 - thermistorLineWidth/2,0, w/2 - thermistorLineTraceSpacing/2 - thermistorLineWidth/2, h/2 - sideA/2 + thermistorLineWidth/2, 0);
    addWire(w/2 - thermistorLineTraceSpacing/2 - thermistorLineWidth/2, h/2 - sideA/2 + thermistorLineWidth/2, w/2 - c/2 + b/2, h/2 - sideA/2 + thermistorLineWidth/2, 0); 
    addWire(w/2 - c/2 + b/2, h/2 - sideA/2 + thermistorLineWidth/2, w/2 - c/2 +b/2, h/2, 0); 
    addPath(pathCount++, wirePath, thermistorLineWidth, "black", xml);
    resetWirePath();
    
    addWire(w/2 + thermistorLineTraceSpacing/2 + thermistorLineWidth/2,0, w/2 + thermistorLineTraceSpacing/2 + thermistorLineWidth/2, h/2 - sideA/2 + thermistorLineWidth/2, 0);
    addWire(w/2 + thermistorLineTraceSpacing/2 + thermistorLineWidth/2, h/2 - sideA/2 + thermistorLineWidth/2, w/2 + c/2 - b/2, h/2 - sideA/2 + thermistorLineWidth/2, 0); 
    addWire(w/2 + c/2 - b/2, h/2 - sideA/2 + thermistorLineWidth/2, w/2 + c/2 -b/2, h/2, 0); 
    addPath(pathCount++, wirePath, thermistorLineWidth, "black", xml);
    resetWirePath();
    

    strokeWeight(thermistorConnect);
    addWire(w/2 - thermistorLineTraceSpacing/2 - thermistorConnect, thermistorConnect/2, w/2 - thermistorLineTraceSpacing/2, thermistorConnect/2, 0);
    addPath(pathCount++, wirePath, thermistorConnect, "black", xml);
    resetWirePath();

    addWire(w/2 + thermistorLineTraceSpacing/2 + thermistorConnect, thermistorConnect/2, w/2 + thermistorLineTraceSpacing/2, thermistorConnect/2, 0);
    addPath(pathCount++, wirePath, thermistorConnect, "black", xml);
    resetWirePath();

    endShape();  
}


void initSMDPackages() {
  smdPackageDimensions.put("0402", new float[] {0.6, 0.6, 1.7});
smdPackageDimensions.put("0603",  new float[] {1.0, 1.0, 3.0});
smdPackageDimensions.put("0805",  new float[] {1.3, 1.2, 3.4});
smdPackageDimensions.put("1206",  new float[] {1.8, 1.2, 4.5});
}