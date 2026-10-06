"""Referencia (Python) del paso 'imagen -> parámetros' de un look.
Entrada: píxeles sRGB (0..1) de una región ya rectificada a UV + píxeles de piel base.
Salida: color objetivo, opacidad y acabado estimados.
La versión de producción se porta a Dart/C++; esto sirve para fijar el algoritmo y los tests."""
import numpy as np

def srgb_to_lin(c): return np.power(np.clip(c,0,1),2.2)
def lin_to_srgb(c): return np.power(np.clip(c,0,1),1/2.2)

def to_ok(rgb_lin):
    M1=np.array([[0.4122214708,0.5363325363,0.0514459929],
                 [0.2119034982,0.6806995451,0.1073969566],
                 [0.0883024619,0.2817188376,0.6299787005]])
    M2=np.array([[0.2104542553,0.7936177850,-0.0040720468],
                 [1.9779984951,-2.4285922050,0.4505937099],
                 [0.0259040371,0.7827717662,-0.8086757660]])
    lms=np.cbrt(np.maximum(rgb_lin@M1.T,0)); return lms@M2.T

def from_ok(lab):
    M2i=np.array([[1,0.3963377774,0.2158037573],
                  [1,-0.1055613458,-0.0638541728],
                  [1,-0.0894841775,-1.2914855480]])
    M1i=np.array([[4.0767416621,-3.3077115913,0.2309699292],
                  [-1.2684380046,2.6097574011,-0.3413193965],
                  [-0.0041960863,-0.7034186147,1.7076147010]])
    return (np.power(lab@M2i.T,3))@M1i.T

def in_gamut(rgb_lin,eps=1e-4): return bool(np.all(rgb_lin>=-eps) and np.all(rgb_lin<=1+eps))

def robust_lab(pix_srgb, drop_hi=0.08, drop_lo=0.05):
    """Mediana en OKLab descartando brillos especulares (L alto) y sombras (L bajo)."""
    lab=to_ok(srgb_to_lin(pix_srgb)); L=lab[:,0]
    lo,hi=np.quantile(L,drop_lo),np.quantile(L,1-drop_hi)
    keep=(L>=lo)&(L<=hi)
    return np.median(lab[keep],axis=0), lab

def gloss_score(lab, hi_delta=0.12, full_at=0.06):
    """Fracción de píxeles claramente más claros que la mediana -> 0..1 (umbrales a calibrar)."""
    L=lab[:,0]; frac=np.mean(L>np.median(L)+hi_delta)
    return float(np.clip(frac/full_at,0,1))

def solve_color_opacity(skin_lab, obs_lab, w_policy):
    """obs = skin + w*(target-skin) en (a,b). Color y opacidad no son identificables por separado:
    se fija w por política y se despeja target; si sale de gamut, se sube w hasta que entre."""
    for w in np.linspace(w_policy,1.0,60):
        t_ab = skin_lab[1:]+(obs_lab[1:]-skin_lab[1:])/w
        t = np.array([0.55,t_ab[0],t_ab[1]])   # L de referencia del shader
        # el color objetivo guardado usa su propia L: se toma la observada (aprox. del color de producto)
        t[0]=obs_lab[0]
        if in_gamut(from_ok(t)): return t,float(w)
    return np.array([obs_lab[0],*obs_lab[1:]]),1.0

def render_ab(skin_lab,target_lab,w):  # mismo mezclado de croma que el shader (lumaFollow=0)
    out=skin_lab.copy(); out[1:]=skin_lab[1:]+w*(target_lab[1:]-skin_lab[1:]); return out

if __name__=="__main__":
    rng=np.random.default_rng(1)
    skin=to_ok(srgb_to_lin(np.array([0.80,0.62,0.52])))
    # --- test 1: identificabilidad: mismo render con (color,opacidad) distintos
    true_target=to_ok(srgb_to_lin(np.array([0.90,0.35,0.40]))); w_true=0.30
    obs=render_ab(skin,true_target,w_true)
    for pol in (0.35,0.6,0.85):
        t,w=solve_color_opacity(skin,obs,pol)
        rec=render_ab(skin,t,w)
        de=np.linalg.norm(rec[1:]-obs[1:])
        print(f"política w={pol:.2f}: opacidad={w:.2f} color_sRGB={np.round(lin_to_srgb(from_ok(t)),3)}  error croma de render={de:.2e}")
    # --- test 2: gloss vs mate sobre región de labio sintética
    n=4000
    base=np.array([0.62,0.18,0.20])
    matte=np.clip(base+rng.normal(0,0.02,(n,3)),0,1)
    gloss=matte.copy(); idx=rng.choice(n,int(0.07*n),replace=False); gloss[idx]=np.clip(gloss[idx]*0.3+0.75,0,1)
    for name,pix in (("mate",matte),("gloss",gloss)):
        med,lab=robust_lab(pix)
        print(f"{name:5s}: color robusto sRGB={np.round(lin_to_srgb(from_ok(med)),3)}  gloss_score={gloss_score(lab):.2f}")
    print("color verdadero base sRGB=",base)
