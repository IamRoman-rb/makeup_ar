"""Red alumna del modelo propio (informe §6.2): MobileNetV3-Small escrita acá,
sin pesos preentrenados (los de ImageNet traen términos de uso que no
verificamos para un producto) y sin depender de torchvision.

Entrada: recorte RGB [0,1] de INPUT_SIZE² (el mismo ROI que el tracker).
Salida: (B, 478, 3) en coordenadas del recorte ([0,1] en x, y; z en la misma
escala) y un logit de presencia de cara (B,). Con [dense_points] > 0 suma un
cabezal denso (B, dense_points, 2): contornos de labios y ojos remuestreados
(dense.py, opción 5 de precisión). El motor solo usa los 478 (export.py).
"""

from __future__ import annotations

import torch
from torch import nn

from geometry import LANDMARK_COUNT

INPUT_SIZE = 192

# (kernel, expansión, salida, squeeze-excite, activación, stride): MobileNetV3-Small.
SMALL_BLOCKS = (
    (3, 16, 16, True, "relu", 2),
    (3, 72, 24, False, "relu", 2),
    (3, 88, 24, False, "relu", 1),
    (5, 96, 40, True, "hswish", 2),
    (5, 240, 40, True, "hswish", 1),
    (5, 240, 40, True, "hswish", 1),
    (5, 120, 48, True, "hswish", 1),
    (5, 144, 48, True, "hswish", 1),
    (5, 288, 96, True, "hswish", 2),
    (5, 576, 96, True, "hswish", 1),
    (5, 576, 96, True, "hswish", 1),
)


def _act(name: str) -> nn.Module:
    return nn.ReLU(inplace=True) if name == "relu" else nn.Hardswish(inplace=True)


def _divisible(value: float, divisor: int = 8) -> int:
    return max(divisor, int(value + divisor / 2) // divisor * divisor)


class ConvBnAct(nn.Sequential):
    def __init__(self, cin: int, cout: int, kernel: int, stride: int = 1, groups: int = 1, act: str | None = "relu"):
        layers: list[nn.Module] = [
            nn.Conv2d(cin, cout, kernel, stride, kernel // 2, groups=groups, bias=False),
            nn.BatchNorm2d(cout),
        ]
        if act is not None:
            layers.append(_act(act))
        super().__init__(*layers)


class SqueezeExcite(nn.Module):
    def __init__(self, channels: int):
        super().__init__()
        hidden = _divisible(channels / 4)
        self.pool = nn.AdaptiveAvgPool2d(1)
        self.fc1 = nn.Conv2d(channels, hidden, 1)
        self.relu = nn.ReLU(inplace=True)
        self.fc2 = nn.Conv2d(hidden, channels, 1)
        self.gate = nn.Hardsigmoid(inplace=True)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return x * self.gate(self.fc2(self.relu(self.fc1(self.pool(x)))))


class InvertedResidual(nn.Module):
    def __init__(self, cin: int, kernel: int, expanded: int, cout: int, se: bool, act: str, stride: int):
        super().__init__()
        self.residual = stride == 1 and cin == cout
        layers: list[nn.Module] = []
        if expanded != cin:
            layers.append(ConvBnAct(cin, expanded, 1, act=act))
        layers.append(ConvBnAct(expanded, expanded, kernel, stride, groups=expanded, act=act))
        if se:
            layers.append(SqueezeExcite(expanded))
        layers.append(ConvBnAct(expanded, cout, 1, act=None))
        self.block = nn.Sequential(*layers)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        out = self.block(x)
        return x + out if self.residual else out


class LandmarkStudent(nn.Module):
    def __init__(self, width: float = 1.0, points: int = LANDMARK_COUNT, head_hidden: int = 1024,
                 dense_points: int = 0):
        super().__init__()
        self.points = points
        self.dense_points = dense_points
        channels = _divisible(16 * width)
        layers: list[nn.Module] = [ConvBnAct(3, channels, 3, 2, act="hswish")]
        for kernel, expanded, out, se, act, stride in SMALL_BLOCKS:
            next_channels = _divisible(out * width)
            layers.append(InvertedResidual(channels, kernel, _divisible(expanded * width), next_channels, se, act,
                                           stride))
            channels = next_channels
        last = _divisible(576 * width)
        layers.append(ConvBnAct(channels, last, 1, act="hswish"))
        self.features = nn.Sequential(*layers)
        self.pool = nn.AdaptiveAvgPool2d(1)
        self.head = nn.Sequential(nn.Flatten(), nn.Linear(last, head_hidden), nn.Hardswish(inplace=True))
        self.landmarks = nn.Linear(head_hidden, points * 3)
        self.presence = nn.Linear(head_hidden, 1)
        self.dense = nn.Linear(head_hidden, dense_points * 2) if dense_points > 0 else None
        # Arranca prediciendo la cara media en el centro del recorte.
        nn.init.zeros_(self.landmarks.weight)
        with torch.no_grad():
            self.landmarks.bias.copy_(torch.tensor([0.5, 0.5, 0.0]).repeat(points))
            if self.dense is not None:
                nn.init.zeros_(self.dense.weight)
                self.dense.bias.fill_(0.5)

    def forward(self, image: torch.Tensor):
        hidden = self.head(self.pool(self.features(image)))
        points = self.landmarks(hidden).view(-1, self.points, 3)
        presence = self.presence(hidden).squeeze(-1)
        if self.dense is None:
            return points, presence
        return points, presence, self.dense(hidden).view(-1, self.dense_points, 2)


def parameter_count(model: nn.Module) -> int:
    return sum(p.numel() for p in model.parameters())
