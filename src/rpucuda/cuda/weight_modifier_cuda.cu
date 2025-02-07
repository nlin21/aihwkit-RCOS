/**
 * (C) Copyright 2020, 2021, 2022 IBM. All Rights Reserved.
 *
 * This code is licensed under the Apache License, Version 2.0. You may
 * obtain a copy of this license in the LICENSE.txt file in the root directory
 * of this source tree or at http://www.apache.org/licenses/LICENSE-2.0.
 *
 * Any modifications or derivative works of this code must retain this
 * copyright notice, and modified files need to carry a notice indicating
 * that they have been altered from the originals.
 */

#include "cuda_math_util.h"
#include "weight_modifier_cuda.h"

namespace RPU {

#define RPU_WM_KERNEL_LOOP(STOCH_IF, BODY)                                                         \
  int tid = blockDim.x * blockIdx.x + threadIdx.x;                                                 \
  int total_threads = blockDim.x * gridDim.x;                                                      \
  int size = size_in;                                                                              \
  int size_without_bias = copy_last_column ? (size - d_size) : size;                               \
  const bool stoch_if = STOCH_IF;                                                                  \
                                                                                                   \
  curandState local_state;                                                                         \
  if (stoch_if && tid < size) {                                                                    \
    local_state = random_states[tid];                                                              \
  }                                                                                                \
                                                                                                   \
  for (int i_stride = 0; i_stride < size; i_stride += total_threads) {                             \
    int i = i_stride + tid;                                                                        \
    if (i < size_without_bias) {                                                                   \
      { BODY; }                                                                                    \
    } else if ((i < size) && (new_weights != weights)) {                                           \
      new_weights[i] = weights[i];                                                                 \
    }                                                                                              \
  }                                                                                                \
                                                                                                   \
  if (stoch_if && tid < size) {                                                                    \
    random_states[tid] = local_state;                                                              \
  }

template <typename T>
__global__ void kernelModifyWeightsDiscretize(
    int size_in,
    int d_size,
    const bool copy_last_column,
    T *new_weights,
    const T *weights,
    const T res_in, // need to larger than zero!!
    const bool sto_round,
    const float assumed_wmax,
    const float *wmax,
    curandState_t *random_states) {
  const T res = res_in;
  T amax = (wmax) ? (*wmax) : assumed_wmax;
  amax = amax > 0.0 ? amax : (T)1.0;

  RPU_WM_KERNEL_LOOP(
      sto_round,

      T value = weights[i] / amax;
      value /= res;

      if (stoch_if) {
        T stoch_value = curand_uniform(&local_state);
        value += stoch_value - 0.5;
      }

      new_weights[i] = amax * res * round(value););
}

template <typename T>
__global__ void kernelModifyWeightsDoReFa(
    int size_in,
    int d_size,
    const bool copy_last_column,
    T *new_weights,
    const T *weights,
    const T res_in, // need to larger than zero!!
    const bool sto_round,
    const T dorefa_clip,
    float assumed_wmax,
    float *wmax,
    curandState_t *random_states) {
  T amax = (wmax) ? (*wmax) : assumed_wmax;
  amax = amax > 0.0 ? amax : (T)1.0;

  const T res = res_in;
  const T scale = fabs(dorefa_clip / tanhf(amax));

  RPU_WM_KERNEL_LOOP(
      sto_round,

      T value = weights[i];
      value = tanhf(value) * scale;

      value /= res;

      if (stoch_if) {
        T stoch_value = curand_uniform(&local_state);
        value += stoch_value - 0.5;
      }

      new_weights[i] = res * round(value););
}

template <typename T>
__global__ void kernelModifyWeightsDiscretizeAddNormal(
    int size_in,
    int d_size,
    const bool copy_last_column,
    T *new_weights,
    const T *weights,
    const T res_in, // need to larger than zero!!
    const bool sto_round_in,
    const T stddev_in,
    const float assumed_wmax,
    const float *wmax,
    curandState_t *random_states) {
  const T res = res_in;
  const T stddev = stddev_in;
  const bool sto_round = sto_round_in;
  T amax = (wmax) ? (*wmax) : assumed_wmax;
  amax = amax > 0.0 ? amax : (T)1.0;

  RPU_WM_KERNEL_LOOP(
      true,

      T value = weights[i] / amax;

      value /= res;

      if (sto_round) { value += curand_uniform(&local_state) - 0.5; }

      value = res * round(value);
      T stoch_value = curand_normal(&local_state);
      new_weights[i] = amax * (value + stddev * stoch_value););
}

template <typename T>
__global__ void kernelModifyWeightsAddNormal(
    int size_in,
    int d_size,
    const bool copy_last_column,
    T *new_weights,
    const T *weights,
    const T stddev_in,
    const float assumed_wmax,
    const float *wmax,
    curandState_t *random_states) {
  T amax = (wmax) ? (*wmax) : assumed_wmax;
  amax = amax > 0.0 ? amax : (T)1.0;

  const T stddev = amax * stddev_in;

  RPU_WM_KERNEL_LOOP(true,

                     T stoch_value = curand_normal(&local_state);
                     new_weights[i] = weights[i] + stddev * stoch_value;);
}

template <typename T>
__global__ void kernelModifyWeightsMultNormal(
    int size_in,
    int d_size,
    const bool copy_last_column,
    T *new_weights,
    const T *weights,
    const T stddev_in,
    const float assumed_wmax,
    const float *wmax,
    curandState_t *random_states) {
  T amax = (wmax) ? (*wmax) : assumed_wmax;
  amax = amax > 0.0 ? amax : (T)1.0;

  const T stddev = stddev_in * amax;

  RPU_WM_KERNEL_LOOP(true,

                     T w = weights[i];
                     T stoch_value = curand_normal(&local_state);

                     new_weights[i] = w * (1 + stddev * stoch_value););
}

template <typename T>
__global__ void kernelModifyWeightsProgNoiseN(
    int size_in,
    int d_size,
    const bool copy_last_column,
    T *new_weights,
    const T *weights,
    const T stddev_in, // additional scale:
    int n_coeffs,
    T *coeffs,
    const float assumed_wmax,
    const float *wmax,
    curandState_t *random_states) {
  T amax = (wmax) ? (*wmax) : assumed_wmax;
  amax = amax > 0.0 ? amax : (T)1.0;

  const T stddev = stddev_in;

  RPU_WM_KERNEL_LOOP(
      true,

      T w = weights[i];
      T stoch_value = curand_normal(&local_state);

      T aw = fabs(w) / amax; T paw = 1; T sig = coeffs[0];

      for (int j = 1; j < n_coeffs; j++) {
        paw *= aw;
        sig += coeffs[j] * paw;
      }

      sig *= stddev;
      new_weights[i] = w + amax * sig * stoch_value;);
}

template <typename T>
__global__ void kernelModifyWeightsProgNoise(
    int size_in,
    int d_size,
    const bool copy_last_column,
    T *new_weights,
    const T *weights,
    const T stddev_in, // additional scale:
    const T p0_in,
    const T p1_in,
    const T p2_in,
    const float assumed_wmax,
    const float *wmax,
    curandState_t *random_states) {

  T amax = (wmax) ? (*wmax) : assumed_wmax;
  amax = amax > 0.0 ? amax : (T)1.0;

  const T stddev = stddev_in;
  const T p0 = p0_in;
  const T p1 = p1_in;
  const T p2 = p2_in;

  RPU_WM_KERNEL_LOOP(true,

                     T w = weights[i];
                     T stoch_value = curand_normal(&local_state);

                     T aw = fabs(w) / amax; T sig = (p0 + aw * p1 + aw * aw * p2) * stddev;
                     new_weights[i] = w + amax * sig * stoch_value;);
}

template <typename T>
__global__ void kernelModifyWeightsDropConnections(
    int size_in,
    int d_size,
    const bool copy_last_column,
    T *new_weights,
    const T *weights,
    const T prob_in,
    curandState_t *random_states) {

  const T prob = prob_in;

  RPU_WM_KERNEL_LOOP(
      true,

      T stoch_value = curand_uniform(&local_state);
      if (stoch_value < prob) { new_weights[i] = (T)0.0; });
}

// ctor
template <typename T>
WeightModifierCuda<T>::WeightModifierCuda(CudaContextPtr context, int x_size, int d_size)
    : context_(context), x_size_(x_size), d_size_(d_size), size_(x_size * d_size),
      enable_during_test_(false) {}

template <typename T>
void WeightModifierCuda<T>::apply(
    T *new_weights, const T *weights, const WeightModifierParameter<T> &wmpar) {

  int nthreads = context_->getNThreads();
  auto s = context_->getStream();
  int nblocks = context_->getNStrideBlocks(size_, nthreads);

  bool done = false;
  enable_during_test_ = wmpar.enable_during_test;

  float *amax = nullptr;
  if (wmpar.rel_to_actual_wmax && wmpar.type != WeightModifierType::Copy) {
    if (!amaximizer_) {
      amaximizer_ = RPU::make_unique<Maximizer<T>>(
          context_, wmpar.copy_last_column ? (size_ - d_size_) : size_, true);
    }
    amaximizer_->compute(weights, 1, false);
    amax = amaximizer_->getMaxValues();
  }

  // note: all methods need to work in
  switch (wmpar.type) {
  case WeightModifierType::Copy: {

    if (new_weights == weights) {
      RPU_FATAL("cannot use WeightModifierType::Copy with in-place weights.");
    }
    // copies below
    break; // maybe dropping below though
  }

  case WeightModifierType::Discretize: {

    if (wmpar.res > 0) {

      kernelModifyWeightsDiscretize<T><<<nblocks, nthreads, 0, s>>>(
          size_, d_size_, wmpar.copy_last_column, new_weights, weights, wmpar.res, wmpar.sto_round,
          wmpar.assumed_wmax, amax,
          wmpar.sto_round ? context_->getRandomStates(nblocks * nthreads) : nullptr);
      done = true;
    }
    break;
  }
  case WeightModifierType::DoReFa: {
    if (wmpar.res > 0) {

      kernelModifyWeightsDoReFa<T><<<nblocks, nthreads, 0, s>>>(
          size_, d_size_, wmpar.copy_last_column, new_weights, weights, wmpar.res, wmpar.sto_round,
          wmpar.dorefa_clip, wmpar.assumed_wmax, amax,
          wmpar.sto_round ? context_->getRandomStates(nblocks * nthreads) : nullptr);
      done = true;
    }
    break;
  }

  case WeightModifierType::MultNormal: {
    if (wmpar.std_dev > 0) {

      kernelModifyWeightsMultNormal<T><<<nblocks, nthreads, 0, s>>>(
          size_, d_size_, wmpar.copy_last_column, new_weights, weights, wmpar.std_dev,
          wmpar.assumed_wmax, amax, context_->getRandomStates(nblocks * nthreads));
      done = true;
    }
    break;
  }

  case WeightModifierType::AddNormal: {
    if (wmpar.std_dev > 0) {

      kernelModifyWeightsAddNormal<T><<<nblocks, nthreads, 0, s>>>(
          size_, d_size_, wmpar.copy_last_column, new_weights, weights, wmpar.std_dev,
          wmpar.assumed_wmax, amax, context_->getRandomStates(nblocks * nthreads));
      done = true;
    }
    break;
  }

  case WeightModifierType::Poly: {
    int n_coeffs = wmpar.coeffs.size();
    if (wmpar.std_dev > 0 && n_coeffs > 0) {

      if (n_coeffs <= 3) {

        kernelModifyWeightsProgNoise<T><<<nblocks, nthreads, 0, s>>>(
            size_, d_size_, wmpar.copy_last_column, new_weights, weights, wmpar.std_dev,
            wmpar.coeffs.at(0), (n_coeffs > 1) ? wmpar.coeffs.at(1) : (T)0.0,
            (n_coeffs > 2) ? wmpar.coeffs.at(2) : (T)0.0, wmpar.assumed_wmax, amax,
            context_->getRandomStates(nblocks * nthreads));

      } else {
        // n-poly

        if (wmpar.coeffs.size() != coeffs_.size() || dev_coeffs_ == nullptr) {
          dev_coeffs_ = RPU::make_unique<CudaArray<T>>(context_, n_coeffs, wmpar.coeffs.data());
          coeffs_ = wmpar.coeffs;
          context_->synchronize();
        } else if (coeffs_ != wmpar.coeffs) {
          dev_coeffs_->assign(wmpar.coeffs.data());
          coeffs_ = wmpar.coeffs;
        }

        kernelModifyWeightsProgNoiseN<T><<<nblocks, nthreads, 0, s>>>(
            size_, d_size_, wmpar.copy_last_column, new_weights, weights, wmpar.std_dev, n_coeffs,
            dev_coeffs_->getData(), wmpar.assumed_wmax, amax,
            context_->getRandomStates(nblocks * nthreads));
      }
      done = true;
    }
    break;
  }
  case WeightModifierType::DiscretizeAddNormal: {
    if (wmpar.res > 0 || wmpar.std_dev > 0) {

      kernelModifyWeightsDiscretizeAddNormal<T><<<nblocks, nthreads, 0, s>>>(
          size_, d_size_, wmpar.copy_last_column, new_weights, weights, wmpar.res, wmpar.sto_round,
          wmpar.std_dev, wmpar.assumed_wmax, amax, context_->getRandomStates(nblocks * nthreads));
      done = true;
    }
    break;
  }

  default:
    RPU_FATAL("Requested WeightModifierType not implemented.");
  }

  // need to copy in case some parameters were set to 0
  if (!done && new_weights != weights) {
    RPU::math::copy<T>(context_, size_, weights, 1, new_weights, 1);
  }

  if (wmpar.pdrop > 0.0) {

    if (new_weights == weights) {
      RPU_FATAL("cannot use pdrop>0 with in-place weights.");
    }

    kernelModifyWeightsDropConnections<T><<<nblocks, nthreads, 0, s>>>(
        size_, d_size_, wmpar.copy_last_column, new_weights, new_weights, wmpar.pdrop,
        context_->getRandomStates(nblocks * nthreads));
  }
}

template class WeightModifierCuda<float>;
#ifdef RPU_USE_DOUBLE
template class WeightModifierCuda<double>;
#endif

#undef RPU_WM_KERNEL_LOOP
} // namespace RPU
