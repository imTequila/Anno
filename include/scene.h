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
  unsigned int g_position, g_normal, g_basecolor, g_rmo, g_emission, g_depth;
  unsigned int quad_vao;
  unsigned int quad_vbo;


  scene_t(std::string filename);
  void read_light(FILE *file);
  material_t *read_material(FILE *file);
  glm::mat4 read_transform(FILE *file);
  model_t* read_model(FILE *file);

  void config_skybox();
  void config_kulla_conty();
  void config_ibl();
  void config_shadow_map();
  void confing_deferred();

  void draw_skybox(camera_t camera);
  void draw_shadow_map(glm::mat4 light_view, glm::mat4 light_projection);
  void draw_scene_forward(camera_t camera);
  void draw_scene_deferred(camera_t camera);
};

#endif