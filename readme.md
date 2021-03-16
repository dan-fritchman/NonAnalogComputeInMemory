

# Non-Analog Compute-in-Memory 

A study of and attempt to realize the benefits of compute-in-memory machine-learning acceleration, without all the nastiness of analog computation. 

## Introduction 

Increased demand for high-performance deep learning and neural-network training and inference has driven a wide array of machine-learning acceleration hardware. Typical such ML accelerators feature large data-parallel arithmetic hardware arrays, such as those for performing rapid dense-matrix multiplication. Such accelerators frequently include more arithmetic capacity than their attached memory systems can supply, rendering them heavily memory-bound. Common tactics for confronting these memory-bandwidth limitations have included ever-larger local caches, often dominating an accelerator's overall die area. 
As machine-learning acceleration occurs in both high-performance and low-power contexts (i.e. on mobile edge devices), the speed and energy-efficiency of these operations is of great interest. 

## Compute-in-Memory 

## Analog Methods 

Analog methods for neural-network acceleration, particularly that of matrix-matrix multiplication, commonly deploy analog-domain processing for one or both of their MACC's attendant arithmetic operation: multiplication and/or addition (accumulation). Analog multiplication is performed either via a physical device characteristic, e.g. transistor voltage-current transfer, RRAM, or ReRAM. Addition and accumulation are most commonly performed either on charge or current, the two analog quantities which tend to sum most straightforwardly. In principle these analog-domain operations can be performed at both high speed and high energy-efficiency, at a cost of low precision and high design effort. As the native format of both upstream and downstrem processing is digital, these analog-computation accelerators require a domain-conversion of both their inputs (DACs) and outputs (ADCs). 
Prior research (Rekhi 2020) which (a) presumes the analog-to-digital conversion as the energy-limiting step, and (b) assumes state-of-the-art ADC performance and efficiency has set an upper bound on the resolution-efficiency trade-off for such analog-computation accelerators. 
But this bound is likely far too permissive. Such accelerators obviously (a) have other energy-consuming elements besides their ADCs, but more importantly, (b) do not necessarily (or even likely) have access or appropriate trade-offs for state-of-the-art data conversion. Such converters often consume substantial die area, and/or require elaborate calibration highly attuned to their use-cases. To the author's knowledge no research-based attempts have been made to capture the performance of converters used in such accelerators relative to the state-of-the-art. 
Furthermore, a substantial complication of analog computation is altogether ignored in Rekhi et al: analog computation is inherently non-deterministic. Analog signals and circuits have irrecoverable sources of thermal, flicker, and shot noise, which can only be designed against and never removed. Some proportion of the time, and analog multiplier will inevitably report that 5 x 5 = 26, or 24: the designer's only available knob is *how often*. This is equivalent to choosing a thermal-noise SNR, a process widely understood in data-conversion literature to quadruple power per added bit. 
The analysis as presented in Rekhi et al implicitly buckets all "AMS Error" as that commonly called *quantization error* or *quantization noise* in data-conversion space. While often fairly intractable across a large batch of devices or at design-time, these errors are determinsitic for a given device once fabricate (under unvarying conditions). Thermal noise, in contrast, varies per operation, including for multiplications included in the same inference cycle. 

## Proposed Work 



## References 

1. Rekhi et al, Analog/Mixed-Signal Hardware Error Modeling for Deep Learning Inference, http://picture.iczhiku.com/resource/ieee/sYItDieaWZRzgNxV.pdf
1. https://drive.google.com/file/d/1iqbQYFaW5E46YK2JEHIYP0M790jnxzyA/view?usp=sharing
1. https://drive.google.com/file/d/1VrnC2Ygd-gY5k7yLTJvrg4y1J5a1vvjv/view?usp=sharing
1. https://drive.google.com/file/d/1SycQizZuUfVcbKkAIWT0-o6s5VhFk6kq/view?usp=sharing
1. https://drive.google.com/file/d/1t_Lz3JqOTOACyyqnJgWeFr6MgvK9TtnU/view?usp=sharing

