#include "scene.h"
#include <cassert>
#include <cstring>
#include <ext/matrix_clip_space.hpp>
#include <ext/matrix_transform.hpp>
#include <glad/glad.h>
#include <iostream>
#include <stb_image.h>

#define LINE_SIZE 256
#define PI 3.1415926f

const unsigned int SCR_WIDTH = 1080;
const unsigned int SCR_HEIGHT = 1080;
const unsigned int SHADOW_WIDTH = 4080;
const unsigned int SHADOW_HEIGHT = 4080;

scene_t::scene_t(std::string filename) {
  char scene_type[LINE_SIZE];
  FILE *file;
  file = fopen(filename.c_str(), "rb");
  assert(file != nullptr);

  int items = fscanf(file, " type: %s", scene_type);
  assert(items == 1);

  read_light(file);

  int num_materials = 0;
  items = fscanf(file, " materials %d:", &num_materials);
  assert(num_materials > 0);
  for (int i = 0; i < num_materials; i++) {
    this->materials.push_back(read_material(file));
  }

  int num_transforms = 0;
  items = fscanf(file, " transforms %d:", &num_transforms);
  assert(num_transforms > 0);
  for (int i = 0; i < num_transforms; i++) {
    this->transforms.push_back(read_transform(file));
  }

  int num_models = 0;
  items = fscanf(file, " models %d:", &num_models);
  assert(num_models > 0);
  for (int i = 0; i < num_models; i++) {
    this->models.push_back(read_model(file));
  }
  shader_t shader_t1("../src/shader/pbr_vertex_shader.glsl",
                    "../src/shader/pbr_fragment_shader.glsl");
  this->shader = shader_t1;

  shader_t shader_t2("../src/shader/geometry_vertex_shader.glsl",
                    "../src/shader/geometry_fragment_shader.glsl");
  this->geometry_shader = shader_t2;

  shader_t shader_t3("../src/shader/shading_vertex_shader.glsl",
                       "../src/shader/shading_fragment_shader.glsl");
  this->quad_shader = shader_t3;

  shader_t shader_t4("../src/shader/post_processing_vertex_shader.glsl",
                       "../src/shader/post_processing_fragment_shader.glsl");
  this->post_shader = shader_t4;

  config_skybox();
  config_kulla_conty();
  config_ibl();
  config_shadow_map();
  confing_deferred();
}

void scene_t::read_light(FILE *file) {
  char header[LINE_SIZE];
  int items;

  items = fscanf(file, " %s", header);
  assert(strcmp(header, "lighting:") == 0);

  char pipe[LINE_SIZE];
  items = fscanf(file, " environment: %s", pipe);
  std::string env(pipe);
  this->environment = env;
  assert(items == 1);
  return;
}

material_t *scene_t::read_material(FILE *file) {
  material_t *material = new material_t();
  int items;
  char path[LINE_SIZE];
  int index;
  items = fscanf(file, " material %d:", &index);
  assert(items == 1);
  items = fscanf(file, " basecolor_factor: %f %f %f %f",
                 &material->basecolor_factor.x, &material->basecolor_factor.y,
                 &material->basecolor_factor.z, &material->basecolor_factor.w);
  assert(items == 4);
  items = fscanf(file, " metalness_factor: %f", &material->metalness_factor);
  assert(items == 1);
  items = fscanf(file, " roughness_factor: %f", &material->roughness_factor);
  assert(items == 1);

  items = fscanf(file, " basecolor_map: %s", path);
  std::string basecolor(path);
  if (basecolor != "null")
    material->basecolor_map = "../assets/" + basecolor;
  else
    material->basecolor_map = "null";
  assert(items == 1);

  items = fscanf(file, " metalness_map: %s", path);
  std::string metalness(path);
  if (metalness != "null")
    material->metalness_map = "../assets/" + metalness;
  else
    material->metalness_map = "null";
  assert(items == 1);

  items = fscanf(file, " roughness_map: %s", path);
  std::string roughness(path);
  if (roughness != "null")
    material->roughness_map = "../assets/" + roughness;
  else
    material->roughness_map = "null";
  assert(items == 1);

  items = fscanf(file, " normal_map: %s", path);
  std::string normal(path);
  if (normal != "null")
    material->normal_map = "../assets/" + normal;
  else
    material->normal_map = "null";
  assert(items == 1);

  items = fscanf(file, " occlusion_map: %s", path);
  std::string occlusion(path);
  if (occlusion != "null")
    material->occlusion_map = "../assets/" + occlusion;
  else
    material->occlusion_map = "null";
  assert(items == 1);

  items = fscanf(file, " emission_map: %s", path);
  std::string emission(path);
  if (emission != "null")
    material->emission_map = "../assets/" + emission;
  else
    material->emission_map = "null";
  assert(items == 1);

  char switcher[LINE_SIZE];
  items = fscanf(file, " double_sided: %s", switcher);
  if (switcher == "off")
    material->double_sided = 0;
  else
    material->double_sided = 1;
  assert(items == 1);

  items = fscanf(file, " enable_blend: %s", switcher);
  if (switcher == "off")
    material->enable_blend = 0;
  else
    material->enable_blend = 1;
  assert(items == 1);

  items = fscanf(file, " alpha_cutoff: %f", &material->alpha_cutoff);
  assert(items == 1);

  return material;
}

glm::mat4 scene_t::read_transform(FILE *file) {
  glm::mat4 transform;
  int items;
  int index;
  items = fscanf(file, " transform %d:", &index);
  assert(items == 1);
  for (int i = 0; i < 4; i++) {
    items = fscanf(file, " %f %f %f %f", &transform[i][0], &transform[i][1],
                   &transform[i][2], &transform[i][3]);
    assert(items == 4);
  }

  return transform;
}

model_t *scene_t::read_model(FILE *file) {
  int index;
  char path[LINE_SIZE];

  int items;
  items = fscanf(file, " model %d:", &index);
  assert(items == 1);

  items = fscanf(file, " mesh: %s", path);
  std::string mesh_path(path);
  if (mesh_path != "null")
    mesh_path = "../assets/" + mesh_path;
  else
    mesh_path = "null";
  assert(items == 1);

  /* no ani support */
  items = fscanf(file, " skeleton: %s", path);
  assert(items == 1);

  items = fscanf(file, " attached: %d", &index);
  assert(items == 1);

  int material_index;
  items = fscanf(file, " material: %d", &material_index);
  assert(items == 1);

  int transform_index;
  items = fscanf(file, " transform: %d", &transform_index);
  assert(items == 1);

  return new model_t(load_mesh(mesh_path), this->materials[material_index],
                     this->transforms[transform_index]);
}

void scene_t::config_skybox() {
  unsigned int skybox_texture;
  glGenTextures(1, &skybox_texture);
  glBindTexture(GL_TEXTURE_CUBE_MAP, skybox_texture);

  std::vector<std::string> textures_faces;
  textures_faces.push_back("../assets/" + this->environment + "/m0_px.hdr");
  textures_faces.push_back("../assets/" + this->environment + "/m0_nx.hdr");
  textures_faces.push_back("../assets/" + this->environment + "/m0_py.hdr");
  textures_faces.push_back("../assets/" + this->environment + "/m0_ny.hdr");
  textures_faces.push_back("../assets/" + this->environment + "/m0_pz.hdr");
  textures_faces.push_back("../assets/" + this->environment + "/m0_nz.hdr");

  int width, height, nrChannels;
  float *data;
  stbi_set_flip_vertically_on_load(0);
  for (unsigned int i = 0; i < textures_faces.size(); i++) {
    data =
        stbi_loadf(textures_faces[i].c_str(), &width, &height, &nrChannels, 0);
    glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, GL_RGB16F, width, height,
                 0, GL_RGB, GL_FLOAT, data);
  }

  glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);

  float cube_vertices[] = {
      -1.0f, -1.0f, -1.0f, 0.0f,  0.0f,  -1.0f, 0.0f,  0.0f,  1.0f,  1.0f,
      -1.0f, 0.0f,  0.0f,  -1.0f, 1.0f,  1.0f,  1.0f,  -1.0f, -1.0f, 0.0f,
      0.0f,  -1.0f, 1.0f,  0.0f,  1.0f,  1.0f,  -1.0f, 0.0f,  0.0f,  -1.0f,
      1.0f,  1.0f,  -1.0f, -1.0f, -1.0f, 0.0f,  0.0f,  -1.0f, 0.0f,  0.0f,
      -1.0f, 1.0f,  -1.0f, 0.0f,  0.0f,  -1.0f, 0.0f,  1.0f,

      -1.0f, -1.0f, 1.0f,  0.0f,  0.0f,  1.0f,  0.0f,  0.0f,  1.0f,  -1.0f,
      1.0f,  0.0f,  0.0f,  1.0f,  1.0f,  0.0f,  1.0f,  1.0f,  1.0f,  0.0f,
      0.0f,  1.0f,  1.0f,  1.0f,  1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f,
      1.0f,  1.0f,  -1.0f, 1.0f,  1.0f,  0.0f,  0.0f,  1.0f,  0.0f,  1.0f,
      -1.0f, -1.0f, 1.0f,  0.0f,  0.0f,  1.0f,  0.0f,  0.0f,

      -1.0f, 1.0f,  1.0f,  -1.0f, 0.0f,  0.0f,  1.0f,  0.0f,  -1.0f, 1.0f,
      -1.0f, -1.0f, 0.0f,  0.0f,  1.0f,  1.0f,  -1.0f, -1.0f, -1.0f, -1.0f,
      0.0f,  0.0f,  0.0f,  1.0f,  -1.0f, -1.0f, -1.0f, -1.0f, 0.0f,  0.0f,
      0.0f,  1.0f,  -1.0f, -1.0f, 1.0f,  -1.0f, 0.0f,  0.0f,  0.0f,  0.0f,
      -1.0f, 1.0f,  1.0f,  -1.0f, 0.0f,  0.0f,  1.0f,  0.0f,

      1.0f,  1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f,  0.0f,  1.0f,  -1.0f,
      -1.0f, 1.0f,  0.0f,  0.0f,  0.0f,  1.0f,  1.0f,  1.0f,  -1.0f, 1.0f,
      0.0f,  0.0f,  1.0f,  1.0f,  1.0f,  -1.0f, -1.0f, 1.0f,  0.0f,  0.0f,
      0.0f,  1.0f,  1.0f,  1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f,  0.0f,
      1.0f,  -1.0f, 1.0f,  1.0f,  0.0f,  0.0f,  0.0f,  0.0f,

      -1.0f, -1.0f, -1.0f, 0.0f,  -1.0f, 0.0f,  0.0f,  1.0f,  1.0f,  -1.0f,
      -1.0f, 0.0f,  -1.0f, 0.0f,  1.0f,  1.0f,  1.0f,  -1.0f, 1.0f,  0.0f,
      -1.0f, 0.0f,  1.0f,  0.0f,  1.0f,  -1.0f, 1.0f,  0.0f,  -1.0f, 0.0f,
      1.0f,  0.0f,  -1.0f, -1.0f, 1.0f,  0.0f,  -1.0f, 0.0f,  0.0f,  0.0f,
      -1.0f, -1.0f, -1.0f, 0.0f,  -1.0f, 0.0f,  0.0f,  1.0f,

      -1.0f, 1.0f,  -1.0f, 0.0f,  1.0f,  0.0f,  0.0f,  1.0f,  1.0f,  1.0f,
      1.0f,  0.0f,  1.0f,  0.0f,  1.0f,  0.0f,  1.0f,  1.0f,  -1.0f, 0.0f,
      1.0f,  0.0f,  1.0f,  1.0f,  1.0f,  1.0f,  1.0f,  0.0f,  1.0f,  0.0f,
      1.0f,  0.0f,  -1.0f, 1.0f,  -1.0f, 0.0f,  1.0f,  0.0f,  0.0f,  1.0f,
      -1.0f, 1.0f,  1.0f,  0.0f,  1.0f,  0.0f,  0.0f,  0.0f};

  glGenVertexArrays(1, &skybox_vao);
  glGenBuffers(1, &skybox_vbo);
  glBindVertexArray(skybox_vao);
  glBindBuffer(GL_ARRAY_BUFFER, skybox_vbo);

  glBufferData(GL_ARRAY_BUFFER, sizeof(cube_vertices), cube_vertices,
               GL_STATIC_DRAW);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void *)0);
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float),
                        (void *)(3 * sizeof(float)));
  glEnableVertexAttribArray(2);
  glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float),
                        (void *)(6 * sizeof(float)));
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindVertexArray(0);

  this->skybox_texture = skybox_texture;

  shader_t shader_t1("../src/shader/skybox_vertex_shader.glsl",
                    "../src/shader/skybox_fragment_shader.glsl");
  this->skybox_shader = shader_t1;
  return;
}

void scene_t::draw_skybox(camera_t camera) {
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_CUBE_MAP, this->skybox_texture);

  glm::mat4 view = camera.GetViewMatrix();
  glm::mat4 skybox_view = glm::mat4(glm::mat3(view));
  glm::mat4 skybox_projection = glm::perspective(glm::radians(camera.Zoom),
                                                (float)SCR_WIDTH / (float)SCR_HEIGHT, 0.1f, 100.0f);
  this->skybox_shader.use();
  this->skybox_shader.setInt("uSkyboxMap", 0);
  this->skybox_shader.setMat4("uProjectionMatrix", skybox_projection);
  this->skybox_shader.setMat4("uViewMatrix", skybox_view);
  glBindFramebuffer(GL_FRAMEBUFFER, 0);

  glEnable(GL_STENCIL_TEST);
  glStencilMask(0xff);
  glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);
  glStencilFunc(GL_NOTEQUAL, 1, 0xFF);

  glDepthFunc(GL_ALWAYS);
  glDepthMask(GL_FALSE);
  glBindVertexArray(this->skybox_vao);
  glDrawArrays(GL_TRIANGLES, 0, 36);
  glDepthMask(GL_TRUE);
  glDepthFunc(GL_LESS);
}

void scene_t::config_kulla_conty() {
  glGenTextures(1, &this->e_lut);
  int width, height, nrChannels;
  stbi_set_flip_vertically_on_load(1);
  unsigned char *data =
      stbi_load("../assets/GGX_E_LUT.png", &width, &height, &nrChannels, 0);
  glBindTexture(GL_TEXTURE_2D, this->e_lut);

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0, GL_RGB,
               GL_UNSIGNED_BYTE, data);
  glGenerateMipmap(GL_TEXTURE_2D);
  stbi_image_free(data);

  glGenTextures(1, &this->e_avg);
  stbi_set_flip_vertically_on_load(1);
  data =
      stbi_load("../assets/GGX_Eavg_LUT.png", &width, &height, &nrChannels, 0);
  glBindTexture(GL_TEXTURE_2D, this->e_avg);

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0, GL_RGB,
               GL_UNSIGNED_BYTE, data);
  glGenerateMipmap(GL_TEXTURE_2D);
  stbi_image_free(data);
}

void scene_t::config_ibl() {
  glGenFramebuffers(1, &this->ibl_fbo);
  glGenRenderbuffers(1, &this->ibl_rbo);
  glBindFramebuffer(GL_FRAMEBUFFER, this->ibl_fbo);
  glBindRenderbuffer(GL_RENDERBUFFER, this->ibl_rbo);
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, 512, 512);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
                            GL_RENDERBUFFER, this->ibl_rbo);

  glm::mat4 projection = glm::perspective(glm::radians(90.0f), 1.0f, 0.1f, 10.0f);
  glm::mat4 views[] = {
      glm::lookAt(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(1.0f, 0.0f, 0.0f),
                  glm::vec3(0.0f, -1.0f, 0.0f)),
      glm::lookAt(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(-1.0f, 0.0f, 0.0f),
                  glm::vec3(0.0f, -1.0f, 0.0f)),
      glm::lookAt(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f, 1.0f, 0.0f),
                  glm::vec3(0.0f, 0.0f, 1.0f)),
      glm::lookAt(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f, -1.0f, 0.0f),
                  glm::vec3(0.0f, 0.0f, -1.0f)),
      glm::lookAt(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f, 0.0f, 1.0f),
                  glm::vec3(0.0f, -1.0f, 0.0f)),
      glm::lookAt(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f, 0.0f, -1.0f),
                  glm::vec3(0.0f, -1.0f, 0.0f))};

  glGenTextures(1, &this->prefilter_map);
  glBindTexture(GL_TEXTURE_CUBE_MAP, this->prefilter_map);
  for (unsigned int i = 0; i < 6; ++i) {
    glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, GL_RGB16F, 512, 512, 0,
                 GL_RGB, GL_FLOAT, nullptr);
  }
  glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER,
                  GL_LINEAR_MIPMAP_LINEAR);
  glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glGenerateMipmap(GL_TEXTURE_CUBE_MAP);

  shader_t prefilter_shader("../src/shader/prefilter_vertex_shader.glsl",
                            "../src/shader/prefilter_fragment_shader.glsl");
  prefilter_shader.use();
  prefilter_shader.setInt("uEnvironmentMap", 0);
  prefilter_shader.setMat4("uProjectionMatrix", projection);
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_CUBE_MAP, this->skybox_texture);

  glBindFramebuffer(GL_FRAMEBUFFER, this->ibl_fbo);
  unsigned int max_level = 5;
  for (unsigned int mip = 0; mip < max_level; mip++) {
    unsigned int width = static_cast<unsigned int>(512 * std::pow(0.5, mip));
    unsigned int height = static_cast<unsigned int>(512 * std::pow(0.5, mip));
    glBindRenderbuffer(GL_RENDERBUFFER, this->ibl_rbo);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, width, height);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);

    glViewport(0, 0, width, height);

    float roughness = (float)mip / (float)(max_level - 1);
    prefilter_shader.setFloat("uRoughness", roughness);
    for (unsigned int i = 0; i < 6; ++i) {
      prefilter_shader.setMat4("uViewMatrix", views[i]);
      glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                             GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
                             this->prefilter_map, mip);
      glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
      glDepthMask(GL_FALSE);
      glBindVertexArray(this->skybox_vao);
      glDrawArrays(GL_TRIANGLES, 0, 36);
      glDepthMask(GL_TRUE);
    }
  }
  glBindFramebuffer(GL_FRAMEBUFFER, 0);

  glGenTextures(1, &this->brdf_lut);
  glBindTexture(GL_TEXTURE_2D, this->brdf_lut);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RG16F, 512, 512, 0, GL_RG, GL_FLOAT, 0);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

  glBindFramebuffer(GL_FRAMEBUFFER, this->ibl_fbo);
  glBindRenderbuffer(GL_RENDERBUFFER, this->ibl_rbo);
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, 512, 512);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,
                         brdf_lut, 0);
  glViewport(0, 0, 512, 512);

  float quad_vertices[] = {
      -1.0f, 1.0f, 0.0f, 0.0f, 1.0f, -1.0f, -1.0f, 0.0f, 0.0f, 0.0f,
      1.0f,  1.0f, 0.0f, 1.0f, 1.0f, 1.0f,  -1.0f, 0.0f, 1.0f, 0.0f,
  };
  unsigned int quad_vao;
  unsigned int quad_vbo;
  glGenBuffers(1, &quad_vbo);
  glGenVertexArrays(1, &quad_vao);
  glBindVertexArray(quad_vao);
  glBindBuffer(GL_ARRAY_BUFFER, quad_vbo);
  glBufferData(GL_ARRAY_BUFFER, sizeof(quad_vertices), &quad_vertices,
               GL_STATIC_DRAW);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void *)0);
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float),
                        (void *)(3 * sizeof(float)));

  shader_t brdf_shader("../src/shader/brdf_vertex_shader.glsl",
                       "../src/shader/brdf_fragment_shader.glsl");
  brdf_shader.use();
  glBindVertexArray(quad_vao);
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  glDepthMask(GL_FALSE);
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
  glDepthMask(GL_TRUE);
  glBindVertexArray(0);
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

void scene_t::config_shadow_map() {
  glGenFramebuffers(1, &this->shadow_fbo);

  glGenTextures(1, &shadow_map);
  glBindTexture(GL_TEXTURE_2D, shadow_map);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT, SHADOW_WIDTH,
               SHADOW_HEIGHT, 0, GL_DEPTH_COMPONENT, GL_FLOAT, nullptr);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

  shader_t shader_t1("../src/shader/shadow_vertex_shader.glsl",
                        "../src/shader/shadow_fragment_shader.glsl");
  this->shadow_shader = shader_t1;
}

void scene_t::draw_shadow_map(glm::mat4 light_view, glm::mat4 light_projection) {
  glBindFramebuffer(GL_FRAMEBUFFER, this->shadow_fbo);
  glClear(GL_DEPTH_BUFFER_BIT);
  glViewport(0, 0, SHADOW_WIDTH, SHADOW_HEIGHT);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, this->shadow_map, 0);

  this->shadow_shader.use();
  this->shadow_shader.setMat4("uViewMatrix", light_view);
  this->shadow_shader.setMat4("uProjectionMatrix", light_projection);
  
  for (int i = 0; i < this->models.size(); i++) {
    glm::mat4 model = glm::mat4(1.0f);
    model = glm::scale(model, glm::vec3(1.0f, 1.0f, 1.0f));
    model = glm::rotate(model, 0.0f, glm::vec3(1.0f, 0.0f, 0.0f));
    model = glm::translate(model, glm::vec3(this->models[i]->transform[0][3],
                                            this->models[i]->transform[1][3],
                                            this->models[i]->transform[2][3]));
    
    this->shadow_shader.setMat4("uModelMatrix", model);
    this->models[i]->draw();
  }
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

void scene_t::draw_scene_forward(camera_t camera) {
  glActiveTexture(GL_TEXTURE6);
  glBindTexture(GL_TEXTURE_2D, this->e_lut);
  glActiveTexture(GL_TEXTURE7);
  glBindTexture(GL_TEXTURE_2D, this->e_avg);
  glActiveTexture(GL_TEXTURE8);
  glBindTexture(GL_TEXTURE_CUBE_MAP, this->prefilter_map);
  glActiveTexture(GL_TEXTURE9);
  glBindTexture(GL_TEXTURE_2D, this->brdf_lut);
  glActiveTexture(GL_TEXTURE10);
  glBindTexture(GL_TEXTURE_2D, this->shadow_map);

  glm::mat4 view = camera.GetViewMatrix();
  glm::mat4 projection = glm::perspective(glm::radians(camera.Zoom),
                                         (float)SCR_WIDTH / (float)SCR_HEIGHT, 0.01f, 100.0f);

  glm::vec3 light_pos(0.0f, 25.0f, 0.0f);
  glm::mat4 light_view = glm::lookAt(light_pos, glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f, 0.0f, 1.0f));
  glm::mat4 light_projection = glm::perspective(glm::radians(camera.Zoom),
                                               (float)SHADOW_WIDTH / (float)SHADOW_HEIGHT, 1.0f, 50.0f);

  draw_shadow_map(light_view, light_projection);

  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  glViewport(0, 0, SCR_WIDTH, SCR_HEIGHT);

  this->shader.use();
  this->shader.setMat4("uViewMatrix", view);
  this->shader.setMat4("uProjectionMatrix", projection);
  this->shader.setVec3("uCameraPos", camera.Position);
  this->shader.setVec3("uLightPos", light_pos);
  this->shader.setMat4("uLightViewMatrix", light_view);
  this->shader.setMat4("uLightProjectionMatrix", light_projection);
  this->shader.setInt("uBasecolorMap", 0);
  this->shader.setInt("uMetalnessMap", 1);
  this->shader.setInt("uRoughnessMap", 2);
  this->shader.setInt("uNormalMap", 3);
  this->shader.setInt("uOcclusionMap", 4);
  this->shader.setInt("uEmissionMap", 5);
  this->shader.setInt("uBRDFLut", 6);
  this->shader.setInt("uEavgLut", 7);
  this->shader.setInt("uPrefilterMap", 8);
  this->shader.setInt("uBRDFLut_ibl", 9);
  this->shader.setInt("uShadowMap", 10);

  for (int i = 0; i < this->models.size(); i++) {
    glm::mat4 model = glm::mat4(1.0f);
    model = glm::scale(model, glm::vec3(1.0f, 1.0f, 1.0f));
    model = glm::rotate(model, 0.0f, glm::vec3(1.0f, 0.0f, 0.0f));
    model = glm::translate(model, glm::vec3(this->models[i]->transform[0][3],
                                            this->models[i]->transform[1][3],
                                            this->models[i]->transform[2][3]));

    this->shader.setMat4("uModelMatrix", model);
    this->shader.setVec4("uBasecolor", this->models[i]->material->basecolor_factor);
    this->shader.setFloat("uMetalness", this->models[i]->material->metalness_factor);
    this->shader.setFloat("uRoughness", this->models[i]->material->roughness_factor);

    if (this->models[i]->normal_map < 0xfff) {
      this->shader.setInt("uEnableBump", 1);
    }else{
      this->shader.setInt("uEnableBump", 0);
    }
    if (this->models[i]->occlusion_map < 0xfff) {
      this->shader.setInt("uEnableOcclusion", 1);
    }else{
      this->shader.setInt("uEnableOcclusion", 0);
    }
    if (this->models[i]->emission_map < 0xfff) {
      this->shader.setInt("uEnableEmission", 1);
    }else{
      this->shader.setInt("uEnableEmission", 0);
    }
    this->models[i]->draw();
  }
}

void scene_t::confing_deferred() {
  glGenFramebuffers(1, &this->geometry_fbo);
  glBindFramebuffer(GL_FRAMEBUFFER, this->geometry_fbo);

  glGenTextures(1, &this->g_position);
  glBindTexture(GL_TEXTURE_2D, this->g_position);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, SCR_WIDTH, SCR_HEIGHT, 0, GL_RGB, GL_FLOAT, NULL);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, this->g_position, 0);

  glGenTextures(1, &this->g_normal);
  glBindTexture(GL_TEXTURE_2D, this->g_normal);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, SCR_WIDTH, SCR_HEIGHT, 0, GL_RGB, GL_FLOAT, NULL);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, this->g_normal, 0);
  
  glGenTextures(1, &this->g_basecolor);
  glBindTexture(GL_TEXTURE_2D, this->g_basecolor);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, SCR_WIDTH, SCR_HEIGHT, 0, GL_RGBA, GL_FLOAT, NULL);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT2, GL_TEXTURE_2D, this->g_basecolor, 0);
  
  // roughness, metallic, occusion
  glGenTextures(1, &this->g_rmo);
  glBindTexture(GL_TEXTURE_2D, this->g_rmo);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, SCR_WIDTH, SCR_HEIGHT, 0, GL_RGB, GL_FLOAT, NULL);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT3, GL_TEXTURE_2D, this->g_rmo, 0);
  
  glGenTextures(1, &this->g_emission);
  glBindTexture(GL_TEXTURE_2D, this->g_emission);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, SCR_WIDTH, SCR_HEIGHT, 0, GL_RGB, GL_FLOAT, NULL);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT4, GL_TEXTURE_2D, this->g_emission, 0);

  glGenTextures(1, &this->g_depth);
  glBindTexture(GL_TEXTURE_2D, this->g_depth);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_R16F, SCR_WIDTH, SCR_HEIGHT, 0, GL_RED, GL_FLOAT, NULL);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT5, GL_TEXTURE_2D, this->g_depth, 0);

  glGenRenderbuffers(1, &geometry_rbo);
  glBindRenderbuffer(GL_RENDERBUFFER, geometry_rbo);
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, SCR_WIDTH, SCR_HEIGHT);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, geometry_rbo);

  unsigned int attachments[6] = {GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2, GL_COLOR_ATTACHMENT3, GL_COLOR_ATTACHMENT4, GL_COLOR_ATTACHMENT5};
  glDrawBuffers(6, attachments);

  if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        std::cout << "Framebuffer not complete!" << std::endl;
  glBindFramebuffer(GL_FRAMEBUFFER, 0);

  glGenFramebuffers(1, &this->shading_fbo);
  glBindFramebuffer(GL_FRAMEBUFFER, this->shading_fbo);

  glGenTextures(1, &this->color_buffer);
  glBindTexture(GL_TEXTURE_2D, this->color_buffer);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, SCR_WIDTH, SCR_HEIGHT, 0, GL_RGBA, GL_FLOAT, NULL);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, this->color_buffer, 0);

  glGenRenderbuffers(1, &shading_rbo);
  glBindRenderbuffer(GL_RENDERBUFFER, shading_rbo);
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT, SCR_WIDTH, SCR_HEIGHT);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, shading_rbo);
  

  if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        std::cout << "Framebuffer not complete!" << std::endl;
  glBindFramebuffer(GL_FRAMEBUFFER, 0);

  float quad_vertices[] = {
      -1.0f, 1.0f, 0.0f, 0.0f, 1.0f, -1.0f, -1.0f, 0.0f, 0.0f, 0.0f,
      1.0f,  1.0f, 0.0f, 1.0f, 1.0f, 1.0f,  -1.0f, 0.0f, 1.0f, 0.0f,
  };
  glGenBuffers(1, &this->quad_vbo);
  glGenVertexArrays(1, &this->quad_vao);
  glBindVertexArray(this->quad_vao);
  glBindBuffer(GL_ARRAY_BUFFER, this->quad_vbo);
  glBufferData(GL_ARRAY_BUFFER, sizeof(quad_vertices), &quad_vertices,
               GL_STATIC_DRAW);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void *)0);
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float),
                        (void *)(3 * sizeof(float)));
  glBindVertexArray(0);
}

static void saveArrayToTextFile(const std::string& filename, const float* array, size_t size) {
    std::ofstream outFile(filename);
    if (!outFile) {
        std::cerr << "Failed to open file for writing: " << filename << std::endl;
        return;
    }

    for (size_t i = 0; i < size; ++i) {
        outFile << array[i] << "\n";
    }

    outFile.close();
    if (!outFile.good()) {
        std::cerr << "Error occurred while writing to file: " << filename << std::endl;
    }
}

void scene_t::draw_scene_deferred(camera_t camera) {
  static int frame_idx = 0;
  glm::mat4 view = camera.GetViewMatrix();
  glm::mat4 projection = glm::perspective(glm::radians(camera.Zoom), 
                                         (float)SCR_WIDTH / (float)SCR_HEIGHT, 0.1f, 100.0f);

  glm::vec3 light_pos(0.0f, 25.0f, 0.0f);
  glm::mat4 light_view = glm::lookAt(light_pos, glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f, 0.0f, 1.0f));
  glm::mat4 light_projection = glm::perspective(glm::radians(camera.Zoom), 
                                               (float)SHADOW_WIDTH / (float)SHADOW_HEIGHT, 1.0f, 50.0f);

  draw_shadow_map(light_view, light_projection);
  
  glBindFramebuffer(GL_FRAMEBUFFER, this->geometry_fbo);
  glEnable(GL_STENCIL_TEST);
  glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
  glStencilFunc(GL_ALWAYS, 1, 0xFF);
  glStencilMask(0xFF);

  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
  glViewport(0, 0, SCR_WIDTH, SCR_HEIGHT);
  
  this->geometry_shader.use();
  this->geometry_shader.setMat4("uViewMatrix", view);
  this->geometry_shader.setMat4("uProjectionMatrix", projection);
  this->geometry_shader.setInt("uOffsetIdx", frame_idx % 8);
  this->geometry_shader.setInt("uBasecolorMap", 0);
  this->geometry_shader.setInt("uMetalnessMap", 1);
  this->geometry_shader.setInt("uRoughnessMap", 2);
  this->geometry_shader.setInt("uNormalMap", 3);
  this->geometry_shader.setInt("uOcclusionMap", 4);
  this->geometry_shader.setInt("uEmissionMap", 5);

  for (int i = 0; i < this->models.size(); i++) {
    glm::mat4 model = glm::mat4(1.0f);
    model = glm::scale(model, glm::vec3(1.0f, 1.0f, 1.0f));
    model = glm::rotate(model, 0.0f, glm::vec3(1.0f, 0.0f, 0.0f));
    model = glm::translate(model, glm::vec3(this->models[i]->transform[0][3],
                                            this->models[i]->transform[1][3],
                                            this->models[i]->transform[2][3]));

    this->geometry_shader.setMat4("uModelMatrix", model);
    this->geometry_shader.setVec4("uBasecolor", this->models[i]->material->basecolor_factor);
    this->geometry_shader.setFloat("uMetalness", this->models[i]->material->metalness_factor);
    this->geometry_shader.setFloat("uRoughness", this->models[i]->material->roughness_factor);

    if (this->models[i]->normal_map < 0xfff) {
      this->geometry_shader.setInt("uEnableBump", 1);
    }else{
      this->geometry_shader.setInt("uEnableBump", 0);
    }
    if (this->models[i]->occlusion_map < 0xfff) {
      this->geometry_shader.setInt("uEnableOcclusion", 1);
    }else{
      this->geometry_shader.setInt("uEnableOcclusion", 0);
    }
    if (this->models[i]->emission_map < 0xfff) {
      this->geometry_shader.setInt("uEnableEmission", 1);
    }else{
      this->geometry_shader.setInt("uEnableEmission", 0);
    }
    this->models[i]->draw();
  }
  glStencilMask(0x00);
  glDisable(GL_STENCIL_TEST);
  glBindFramebuffer(GL_FRAMEBUFFER, 0);

  /* shading pass */
  glBindFramebuffer(GL_FRAMEBUFFER, this->shading_fbo);
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  glViewport(0, 0, SCR_WIDTH, SCR_HEIGHT);

  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, this->g_position);
  glActiveTexture(GL_TEXTURE1);
  glBindTexture(GL_TEXTURE_2D, this->g_normal);
  glActiveTexture(GL_TEXTURE2);
  glBindTexture(GL_TEXTURE_2D, this->g_basecolor);
  glActiveTexture(GL_TEXTURE3);
  glBindTexture(GL_TEXTURE_2D, this->g_rmo);
  glActiveTexture(GL_TEXTURE4);
  glBindTexture(GL_TEXTURE_2D, this->g_emission);
  glActiveTexture(GL_TEXTURE5);
  glBindTexture(GL_TEXTURE_2D, this->g_depth);

  glActiveTexture(GL_TEXTURE6);
  glBindTexture(GL_TEXTURE_2D, this->e_lut);
  glActiveTexture(GL_TEXTURE7);
  glBindTexture(GL_TEXTURE_2D, this->e_avg);
  glActiveTexture(GL_TEXTURE8);
  glBindTexture(GL_TEXTURE_2D, this->brdf_lut);
  glActiveTexture(GL_TEXTURE9);
  glBindTexture(GL_TEXTURE_2D, this->shadow_map);
  
  this->quad_shader.use();

  this->quad_shader.setMat4("uViewMatrix", view);
  this->quad_shader.setMat4("uProjectionMatrix", projection);
  this->quad_shader.setVec3("uCameraPos", camera.Position);
  this->quad_shader.setVec3("uLightPos", light_pos);
  this->quad_shader.setInt("uPosition", 0);         /* needed in post processing */
  this->quad_shader.setInt("uNormal", 1);           /* needed in post processing */
  this->quad_shader.setInt("uBasecolor", 2);        /* needed in post processing */
  this->quad_shader.setInt("uRMO", 3);              /* needed in post processing */
  this->quad_shader.setInt("uEmission", 4);
  this->quad_shader.setInt("uDepth", 5);            /* needed in post processing */
  this->quad_shader.setInt("uBRDFLut", 6);
  this->quad_shader.setInt("uEavgLut", 7);
  this->quad_shader.setInt("uBRDFLut_ibl", 8);      /* needed in post processing */
  this->quad_shader.setInt("uShadowMap", 9);
  
  glBindVertexArray(this->quad_vao);
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

  glBindFramebuffer(GL_FRAMEBUFFER, 0);

  glBindFramebuffer(GL_READ_FRAMEBUFFER, this->geometry_fbo);
  glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
  glBlitFramebuffer(0, 0, SCR_WIDTH, SCR_HEIGHT, 0, 0, SCR_WIDTH, SCR_HEIGHT, GL_STENCIL_BUFFER_BIT, GL_NEAREST);

  /* post processing pass */
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  glViewport(0, 0, SCR_WIDTH, SCR_HEIGHT);

  glActiveTexture(GL_TEXTURE11);
  glBindTexture(GL_TEXTURE_2D, this->color_buffer);
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, this->g_position);
  glActiveTexture(GL_TEXTURE1);
  glBindTexture(GL_TEXTURE_2D, this->g_normal);
  glActiveTexture(GL_TEXTURE2);
  glBindTexture(GL_TEXTURE_2D, this->g_basecolor);
  glActiveTexture(GL_TEXTURE3);
  glBindTexture(GL_TEXTURE_2D, this->g_rmo);
  glActiveTexture(GL_TEXTURE4);
  glBindTexture(GL_TEXTURE_2D, this->g_depth);
  glActiveTexture(GL_TEXTURE5);
  glBindTexture(GL_TEXTURE_2D, this->brdf_lut);
  glActiveTexture(GL_TEXTURE6);
  glBindTexture(GL_TEXTURE_CUBE_MAP, this->prefilter_map);



  this->post_shader.use();
  this->post_shader.setInt("uShadingColor", 11);
  this->post_shader.setInt("uPosition", 0);
  this->post_shader.setInt("uNormal", 1);
  this->post_shader.setInt("uBaseColor", 2);
  this->post_shader.setInt("uRMO", 3);
  this->post_shader.setInt("uDepth", 4);
  this->post_shader.setInt("uBRDFLut_ibl", 5);
  this->post_shader.setInt("uPrefilterMap", 6);

  this->post_shader.setMat4("uViewMatrix", view);
  this->post_shader.setMat4("uProjectionMatrix", projection);
  this->post_shader.setVec3("uCameraPos", camera.Position);
  glBindVertexArray(this->quad_vao);
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
  
  frame_idx ++;

}