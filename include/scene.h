#pragma once
#ifndef SCENE_H
#define SCENE_H

#include <glm.hpp>
#include <string>
#include <vector>

#include "model.h"
#include "shader.h"
#include "camera.h"

class scene_t {
public:
  std::vector<model_t *> models;
  std::vector<material_t *> materials;
  std::vector<glm::mat4> transforms;
  std::string environment;

  shader_t shader;
  shader_t geometry_shader;
  shader_t skybox_shader;
  shader_t shadow_shader;
  shader_t quad_shader;
  shader_t post_shader;
  shader_t taa_shader;
  shader_t final_shader;
  
  unsigned int e_avg;
  unsigned int e_lut;

  unsigned int skybox_texture;
  unsigned int skybox_vao;
  unsigned int skybox_vbo;

  unsigned int prefilter_map;
  unsigned int brdf_lut;
  unsigned int ibl_fbo;
  unsigned int ibl_rbo;

  unsigned int shadow_map;
  unsigned int shadow_fbo;

  unsigned int geometry_fbo;
  unsigned int geometry_rbo;
  unsigned int g_position, g_normal, g_basecolor, g_rmo, g_emission, g_depth, g_velocity;

  unsigned int shading_fbo;
  unsigned int shading_rbo;
  unsigned int color_buffer;
  unsigned int final_color;

  unsigned int post_fbo;
  unsigned int post_rbo;
  unsigned int cur_frame;
  unsigned int pre_frame;

  unsigned int taa_fbo;
  unsigned int taa_rbo;

  unsigned int quad_vao;
  unsigned int quad_vbo;



  scene_t(std::string filename);
  void readLight(FILE *file);
  material_t *readMaterial(FILE *file);
  glm::mat4 readTransform(FILE *file);
  model_t* readModel(FILE *file);

  void configSkybox();
  void configKullaConty();
  void configIBL();
  void configShadowMap();
  void configDeferred();

  void drawSkybox(camera_t camera);
  void drawShadowMap(glm::mat4 light_view, glm::mat4 light_projection);
  void drawSceneForward(camera_t camera);
  void drawSceneDeferred(camera_t camera);
};

#endif