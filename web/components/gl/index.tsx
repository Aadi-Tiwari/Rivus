import { Effects } from "@react-three/drei";
import { Canvas } from "@react-three/fiber";
import { Particles } from "./particles";
import { VignetteShader } from "./shaders/vignetteShader";

// Tuned values, frozen. These used to come from a leva panel, which shipped a debug
// GUI and its dependency into the production bundle for settings nobody adjusts.
const FIELD = {
  speed: 1.0,
  noiseScale: 0.6,
  noiseIntensity: 0.52,
  timeScale: 1,
  focus: 3.8,
  aperture: 1.79,
  pointSize: 10.0,
  opacity: 0.5,
  planeScale: 10.0,
  size: 512,
  vignetteDarkness: 0.5,
  vignetteOffset: 0.9,
};

export const GL = ({ hovering }: { hovering: boolean }) => {
  return (
    <div id="webgl">
      <Canvas
        camera={{
          position: [
            1.2629783123314589, 2.664606471394044, -1.8178993743288914,
          ],
          fov: 50,
          near: 0.01,
          far: 300,
        }}
      >
        <color attach="background" args={["#00070F"]} />
        <Particles
          speed={FIELD.speed}
          aperture={FIELD.aperture}
          focus={FIELD.focus}
          size={FIELD.size}
          noiseScale={FIELD.noiseScale}
          noiseIntensity={FIELD.noiseIntensity}
          timeScale={FIELD.timeScale}
          pointSize={FIELD.pointSize}
          opacity={FIELD.opacity}
          planeScale={FIELD.planeScale}
          introspect={hovering}
          position={[0, -0.9, 0]}
        />
        <Effects multisamping={0} disableGamma>
          <shaderPass
            args={[VignetteShader]}
            uniforms-darkness-value={FIELD.vignetteDarkness}
            uniforms-offset-value={FIELD.vignetteOffset}
          />
        </Effects>
      </Canvas>
    </div>
  );
};
