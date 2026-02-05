//
//  DSPUtilities.hpp
//  Vox
//
//  Created by Mark Pauley on 5/18/25.
//

#ifdef __cplusplus

struct DSPUtilities {
public:
    static inline float clamp(float value, float min, float max) {
        if (value < min) return min;
        if (value > max) return max;
        return value;
    }

    static inline float tanh_approx(float x) {
        // Fast approximation of tanh
        // This avoids expensive transcendental function calls
        if (x < -4.0f) return -1.0f;
        else if (x > 4.0f) return 1.0f;
        else {
            // From the lamberts continued fraction expansion of tanh:
            // https://varietyofsound.wordpress.com/2011/02/14/efficient-tanh-computation-using-lamberts-continued-fraction/
            //
            float x_squared = x * x;
            float a = (((x_squared + 378.f) * x_squared + 17325) * x_squared + 135135.f) * x;
            float b = (((28.f * x_squared) + 3150.f) * x_squared + 62370.f) * x_squared + 135135;

            return a / b;
        }
    }
};

#endif
