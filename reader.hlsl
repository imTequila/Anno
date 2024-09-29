float3 CompositeReflectionCapturesAndSkylight(
	float CompositeAlpha,
	float3 WorldPosition,
	float3 RayDirection,
	float Roughness,
	float IndirectIrradiance,
	float IndirectSpecularOcclusion,
	float3 ExtraIndirectSpecular,
	uint NumCapturesAffectingTile,
	uint CaptureDataStartIndex,
	int SingleCaptureIndex,
	bool bCompositeSkylight,
	uint EyeIndex)
{
	float Mip = ComputeReflectionCaptureMipFromRoughness(Roughness, View_ReflectionCubemapMaxMip);
	float4 ImageBasedReflections = float4(0, 0, 0, CompositeAlpha);
	float2 CompositedAverageBrightness = float2(0.0f, 1.0f);



	[loop]
	for (uint TileCaptureIndex = 0; TileCaptureIndex < NumCapturesAffectingTile; TileCaptureIndex++)
	{
		[branch]
		if (ImageBasedReflections.a < 0.001)
		{
			break;
		}

		uint CaptureIndex = 0;

		CaptureIndex = ForwardLightData_CulledLightDataGrid[CaptureDataStartIndex + TileCaptureIndex];

		float4 CapturePositionAndRadius = ReflectionCapture_PositionAndRadius[CaptureIndex];
		float4 CaptureProperties = ReflectionCapture_CaptureProperties[CaptureIndex];

		float3 CaptureVector = WorldPosition - CapturePositionAndRadius.xyz;
		float CaptureVectorLength = sqrt(dot(CaptureVector, CaptureVector));
		float NormalizedDistanceToCapture = saturate(CaptureVectorLength / CapturePositionAndRadius.w);

		[branch]
		if (CaptureVectorLength < CapturePositionAndRadius.w)
		{
			float3 ProjectedCaptureVector = RayDirection;
			float4 CaptureOffsetAndAverageBrightness = ReflectionCapture_CaptureOffsetAndAverageBrightness[CaptureIndex];


			float DistanceAlpha = 0;


















					{
						ProjectedCaptureVector = GetLookupVectorForSphereCapture(RayDirection, WorldPosition, CapturePositionAndRadius, NormalizedDistanceToCapture, CaptureOffsetAndAverageBrightness.xyz, DistanceAlpha);
					}





			float CaptureArrayIndex = CaptureProperties.g;

			{
				float4 Sample = ReflectionStruct_ReflectionCubemap.SampleLevel(ReflectionStruct_ReflectionCubemapSampler, float4(ProjectedCaptureVector, CaptureArrayIndex), Mip);

				Sample.rgb *= CaptureProperties.r;
				Sample *= DistanceAlpha;


				ImageBasedReflections.rgb += Sample.rgb * ImageBasedReflections.a * IndirectSpecularOcclusion;
				ImageBasedReflections.a *= 1 - Sample.a;

				float AverageBrightness = CaptureOffsetAndAverageBrightness.w;
				CompositedAverageBrightness.x += AverageBrightness * DistanceAlpha * CompositedAverageBrightness.y;
				CompositedAverageBrightness.y *= 1 - DistanceAlpha;
			}
		}
	}




































	ImageBasedReflections.rgb *= View_IndirectLightingColorScale;
	CompositedAverageBrightness.x *= Luminance( View_IndirectLightingColorScale );



	[branch]
	if (ReflectionStruct_SkyLightParameters.y > 0 && bCompositeSkylight)
	{
		float SkyAverageBrightness = 1.0f;


			float3 SkyLighting = GetSkyLightReflectionSupportingBlend(RayDirection, Roughness, SkyAverageBrightness);





		bool bNormalize = ReflectionStruct_SkyLightParameters.z < 1 &&  1 ;

		[flatten]
		if (bNormalize)
		{
			ImageBasedReflections.rgb += ImageBasedReflections.a * SkyLighting * IndirectSpecularOcclusion;
			CompositedAverageBrightness.x += SkyAverageBrightness * CompositedAverageBrightness.y;
		}
		else
		{
			ExtraIndirectSpecular += SkyLighting * IndirectSpecularOcclusion;
		}
	}



	ImageBasedReflections.rgb *= ComputeMixingWeight(IndirectIrradiance, CompositedAverageBrightness.x, Roughness);


	ImageBasedReflections.rgb += ImageBasedReflections.a * ExtraIndirectSpecular;

	return ImageBasedReflections.rgb;
}

float3 CompositeReflectionCapturesAndSkylight(
	float CompositeAlpha,
	float3 WorldPosition,
	float3 RayDirection,
	float Roughness,
	float IndirectIrradiance,
	float IndirectSpecularOcclusion,
	float3 ExtraIndirectSpecular,
	uint NumCapturesAffectingTile,
	uint CaptureDataStartIndex,
	int SingleCaptureIndex,
	bool bCompositeSkylight)
{
	return CompositeReflectionCapturesAndSkylight(
		CompositeAlpha,
		WorldPosition,
		RayDirection,
		Roughness,
		IndirectIrradiance,
		IndirectSpecularOcclusion,
		ExtraIndirectSpecular,
		NumCapturesAffectingTile,
		CaptureDataStartIndex,
		SingleCaptureIndex,
		bCompositeSkylight,
		0);
}